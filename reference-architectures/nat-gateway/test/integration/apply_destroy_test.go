package integration

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/charmbracelet/keygen"
	"github.com/digitalocean/godo"
	"github.com/digitalocean/scale-with-simplicity/test/helper"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestApplyAndDestroy(t *testing.T) {
	t.Parallel()

	// Generate unique test prefix (must start with letter for K8s cluster naming)
	testNamePrefix := fmt.Sprintf("test-%s", strings.ToLower(random.UniqueId()))
	logger.Logf(t, "Test name prefix: %s", testNamePrefix)

	// Create API client and CIDR assigner
	ctx := context.Background()
	client := helper.CreateGodoClient()
	cidrAssigner := helper.NewCidrAssigner(ctx, client)

	// Allocate non-overlapping CIDR blocks
	vpcCidr := cidrAssigner.GetVpcCidr()
	clusterCidr := cidrAssigner.GetDoksClusterCidr()
	serviceCidr := cidrAssigner.GetDoksServiceCidr()
	logger.Logf(t, "Allocated VPC CIDR: %s, Cluster CIDR: %s, Service CIDR: %s", vpcCidr, clusterCidr, serviceCidr)

	// Generate SSH key for Droplet access
	sshKeyPair, sshKey := helper.CreateSshKey(client, testNamePrefix)
	defer helper.DeleteSshKey(client, sshKey.ID)
	logger.Logf(t, "Created SSH key: %s (ID: %d)", sshKey.Name, sshKey.ID)

	// Copy entire terraform directory to preserve relative path structure for remote_state
	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
	logger.Logf(t, "Copied terraform directory to: %s", testDir)

	// Copy test.tfvars for Stack 1
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "1-infra", "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars: %v", err)
	}

	// Configure Terraform options for Stack 1 (infra)
	stack1Options := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(testDir, "1-infra"),
		MixedVars: []terraform.Var{
			terraform.VarFile("test.tfvars"),
			terraform.VarInline("name_prefix", testNamePrefix),
			terraform.VarInline("vpc_cidr", vpcCidr),
			terraform.VarInline("doks_cluster_subnet", clusterCidr),
			terraform.VarInline("doks_service_subnet", serviceCidr),
			terraform.VarInline("ssh_key_ids", []string{fmt.Sprintf("%d", sshKey.ID)}),
		},
		NoColor: true,
	})

	// Ensure cleanup happens in correct order
	defer helper.TerraformDestroyVpcWithMembers(t, stack1Options)

	// Apply Stack 1 (infrastructure)
	logger.Log(t, "Applying Stack 1 (infrastructure)...")
	terraform.InitAndApply(t, stack1Options)

	// Get outputs from Stack 1
	clusterName := terraform.Output(t, stack1Options, "cluster_name")
	natPublicIP := terraform.Output(t, stack1Options, "nat_gateway_public_ip")
	bastionPublicIP := terraform.Output(t, stack1Options, "bastion_public_ip")
	dropletPrivateIP := terraform.Output(t, stack1Options, "droplet_private_ip")
	logger.Logf(t, "Stack 1 outputs - Cluster: %s, NAT Public IP: %s, Bastion IP: %s, Droplet Private IP: %s",
		clusterName, natPublicIP, bastionPublicIP, dropletPrivateIP)

	// Configure Terraform options for Stack 2 (routes)
	// NO variables needed - Stack 2 reads everything from ../1-infra/terraform.tfstate
	stack2Options := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(testDir, "2-routes"),
		NoColor:      true,
	})

	// Ensure Stack 2 is destroyed before Stack 1
	defer terraform.Destroy(t, stack2Options)

	// Apply Stack 2 (routes)
	logger.Log(t, "Applying Stack 2 (routing configuration)...")
	terraform.InitAndApply(t, stack2Options)

	// Give the Route CRD time to be processed by the Routing Agent
	logger.Log(t, "Waiting for Route CRD to be processed...")
	time.Sleep(30 * time.Second)

	// Write kubeconfig to temp file for kubectl access
	kubeconfigPath := filepath.Join(testDir, "kubeconfig.yaml")

	// Configure kubectl using the cluster endpoint and credentials from Stack 1
	logger.Log(t, "Configuring kubectl access to cluster...")
	kubectlOptions := configureKubectl(t, client, clusterName, kubeconfigPath)

	// Verify egress routing from Kubernetes Pod
	logger.Log(t, "Verifying egress routing from Kubernetes pod...")
	verifyPodEgress(t, kubectlOptions, natPublicIP)

	// Verify egress routing from Droplet (via bastion)
	logger.Log(t, "Verifying egress routing from Droplet (via bastion)...")
	verifyDropletEgress(t, bastionPublicIP, dropletPrivateIP, natPublicIP, sshKeyPair)

	logger.Log(t, "All validations passed!")
}

// configureKubectl writes the kubeconfig file and returns kubectl options
func configureKubectl(t *testing.T, client *godo.Client, clusterName string, kubeconfigPath string) *k8s.KubectlOptions {
	ctx := context.Background()

	// Get the cluster's kubeconfig via DigitalOcean API
	logger.Logf(t, "Fetching kubeconfig for cluster: %s", clusterName)

	// List all clusters and find ours by name
	clusters, _, err := client.Kubernetes.List(ctx, nil)
	if err != nil {
		t.Fatalf("Failed to list clusters: %v", err)
	}

	var clusterID string
	for _, cluster := range clusters {
		if cluster.Name == clusterName {
			clusterID = cluster.ID
			break
		}
	}

	if clusterID == "" {
		t.Fatalf("Cluster %s not found", clusterName)
	}

	// Get kubeconfig for the cluster
	kubeconfig, _, err := client.Kubernetes.GetKubeConfig(ctx, clusterID)
	if err != nil {
		t.Fatalf("Failed to get kubeconfig: %v", err)
	}

	// Write kubeconfig content to file
	err = os.WriteFile(kubeconfigPath, kubeconfig.KubeconfigYAML, 0600)
	if err != nil {
		t.Fatalf("Failed to write kubeconfig: %v", err)
	}

	logger.Logf(t, "Kubeconfig written to: %s", kubeconfigPath)

	// Return kubectl options with the kubeconfig path
	return k8s.NewKubectlOptions("", kubeconfigPath, "default")
}

// verifyPodEgress verifies that a pod's egress traffic uses the NAT Gateway public IP
func verifyPodEgress(t *testing.T, kubectlOptions *k8s.KubectlOptions, expectedIP string) {
	// Run a test pod that curls ifconfig.me using the generic helper
	result, err := helper.RunPod(t, kubectlOptions, helper.PodRunOptions{
		Name:           "test-egress",
		Image:          "curlimages/curl:latest",
		Command:        []string{"sh", "-c", "curl -s ifconfig.me"},
		MaxWaitSeconds: 60,
	})
	if err != nil {
		t.Fatalf("Failed to run egress test pod: %v", err)
	}

	// Verify the IP matches NAT Gateway public IP
	actualIP := strings.TrimSpace(result.Logs)
	logger.Logf(t, "Pod egress IP: %s, Expected NAT IP: %s", actualIP, expectedIP)
	if actualIP != expectedIP {
		t.Errorf("Pod egress IP (%s) does not match NAT Gateway public IP (%s)", actualIP, expectedIP)
	} else {
		logger.Logf(t, "✓ Pod egress IP matches NAT Gateway public IP")
	}
}

// verifyDropletEgress verifies that the Droplet's egress traffic uses the NAT Gateway public IP
// This function connects to the droplet via the bastion host using SSH ProxyCommand
func verifyDropletEgress(t *testing.T, bastionIP string, dropletPrivateIP string, expectedIP string, keyPair *keygen.KeyPair) {
	description := "Verifying Droplet egress IP via SSH (through bastion)"
	maxRetries := 15
	timeBetweenRetries := 10 * time.Second

	// Write SSH private key to temporary file for SSH command
	tmpKeyFile, err := os.CreateTemp("", "nat-gw-test-key-*")
	if err != nil {
		t.Fatalf("Failed to create temp key file: %v", err)
	}
	defer os.Remove(tmpKeyFile.Name())

	// Write private key and set proper permissions
	if _, err := tmpKeyFile.Write(keyPair.RawPrivateKey()); err != nil {
		t.Fatalf("Failed to write private key: %v", err)
	}
	if err := tmpKeyFile.Close(); err != nil {
		t.Fatalf("Failed to close key file: %v", err)
	}
	if err := os.Chmod(tmpKeyFile.Name(), 0600); err != nil {
		t.Fatalf("Failed to set key file permissions: %v", err)
	}

	logger.Logf(t, "SSH key written to: %s", tmpKeyFile.Name())

	// Wait for SSH to be available and verify egress IP
	actualIP := retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		// Build SSH command with ProxyCommand to access droplet via bastion
		// ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		//     -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no -i <key> root@<bastion>" \
		//     -i <key> root@<droplet-private-ip> "curl -s --max-time 10 ifconfig.me"
		proxyCmd := fmt.Sprintf("ssh -W %%h:%%p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %s root@%s",
			tmpKeyFile.Name(), bastionIP)

		cmd := exec.Command("ssh",
			"-o", "StrictHostKeyChecking=no",
			"-o", "UserKnownHostsFile=/dev/null",
			"-o", fmt.Sprintf("ProxyCommand=%s", proxyCmd),
			"-i", tmpKeyFile.Name(),
			fmt.Sprintf("root@%s", dropletPrivateIP),
			"curl -s --max-time 10 ifconfig.me")

		output, err := cmd.CombinedOutput()
		if err != nil {
			return "", fmt.Errorf("SSH command failed: %v, output: %s", err, string(output))
		}

		// SSH may include warning messages about known_hosts, so extract the last line
		// which contains the actual curl output
		lines := strings.Split(strings.TrimSpace(string(output)), "\n")
		result := strings.TrimSpace(lines[len(lines)-1])

		if result == "" {
			return "", fmt.Errorf("empty response from ifconfig.me")
		}

		return result, nil
	})

	// Verify the IP matches NAT Gateway public IP
	actualIP = strings.TrimSpace(actualIP)
	logger.Logf(t, "Droplet egress IP: %s, Expected NAT IP: %s", actualIP, expectedIP)
	if actualIP != expectedIP {
		t.Errorf("Droplet egress IP (%s) does not match NAT Gateway public IP (%s)", actualIP, expectedIP)
	} else {
		logger.Logf(t, "✓ Droplet egress IP matches NAT Gateway public IP (via bastion)")
	}
}
