package integration

import (
	"context"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2Types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/digitalocean/scale-with-simplicity/test/helper"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"io"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
	"path/filepath"
	"time"

	"strings"
	"testing"
)

// getVpnConnectionTelemetryStatus looks up the first VPN connection tagged Instance=<tagValue> and returns its first VGW telemetry Status.
func getVpnConnectionTelemetryStatus(ctx context.Context, client *ec2.Client, tagValue string) (ec2Types.TelemetryStatus, error) {
	input := &ec2.DescribeVpnConnectionsInput{
		Filters: []ec2Types.Filter{
			{
				Name:   aws.String("tag:Instance"),
				Values: []string{tagValue},
			},
		},
	}

	resp, err := client.DescribeVpnConnections(ctx, input)
	if err != nil {
		return "", fmt.Errorf("DescribeVpnConnections failed: %w", err)
	}
	if len(resp.VpnConnections) == 0 {
		return "", fmt.Errorf("no VPN connections found with tag Instance=%s", tagValue)
	}

	vpn := resp.VpnConnections[0]
	if len(vpn.VgwTelemetry) == 0 {
		return "", fmt.Errorf("no VgwTelemetry entries for VPN connection %s", aws.ToString(vpn.VpnConnectionId))
	}

	return vpn.VgwTelemetry[0].Status, nil
}

// verifyVpnUp waits an initial delay, then polls the VPN telemetry up to maxRetries times
// (sleeping retryDelay between each), and fails the test if it never reports UP.
func verifyVpnUp(t *testing.T, ctx context.Context, client *ec2.Client, tagValue string) {
	const (
		initialDelay = 5 * time.Minute
		retryDelay   = 1 * time.Minute
		maxRetries   = 5
	)

	t.Logf("Waiting %s for VPN to initialize…", initialDelay)
	time.Sleep(initialDelay)

	for i := 1; i <= maxRetries; i++ {
		status, err := getVpnConnectionTelemetryStatus(ctx, client, tagValue)
		if err != nil {
			t.Fatalf("error fetching VPN telemetry (attempt %d): %v", i, err)
		}
		if status == ec2Types.TelemetryStatusUp {
			t.Logf("✅ VPN is UP (on attempt %d)", i)
			return
		}
		t.Logf("Attempt %d/%d: VPN status is %s; retrying in %s…", i, maxRetries, status, retryDelay)
		time.Sleep(retryDelay)
	}

	t.Fatalf("VPN never reached UP after %d attempts (~%s)", maxRetries, initialDelay+retryDelay*time.Duration(maxRetries))
}

// verifyPing spins up a netshoot pod that pings instanceIP 4× and returns an error if the pod fails or if packet loss is non-zero.
func verifyPing(k8sClient *kubernetes.Clientset, instanceIP string) error {
	ctx := context.Background()

	pod := &v1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			GenerateName: "ping-",
			Namespace:    "default",
		},
		Spec: v1.PodSpec{
			RestartPolicy: v1.RestartPolicyNever,
			Containers: []v1.Container{{
				Name:    "ping-test",
				Image:   "nicolaka/netshoot",
				Command: []string{"ping", "-c", "4", instanceIP},
			}},
		},
	}

	pod, err := k8sClient.CoreV1().Pods("default").Create(ctx, pod, metav1.CreateOptions{})
	if err != nil {
		return fmt.Errorf("create ping pod: %w", err)
	}

	// wait for pod to finish
	if err := wait.Poll(5*time.Second, 2*time.Minute, func() (bool, error) {
		p, err := k8sClient.CoreV1().Pods("default").Get(ctx, pod.Name, metav1.GetOptions{})
		if err != nil {
			return false, err
		}
		return p.Status.Phase == v1.PodSucceeded || p.Status.Phase == v1.PodFailed, nil
	}); err != nil {
		return fmt.Errorf("pod did not complete: %w", err)
	}

	// grab logs
	logReq := k8sClient.CoreV1().Pods("default").GetLogs(pod.Name, &v1.PodLogOptions{})
	stream, err := logReq.Stream(ctx)
	if err != nil {
		return fmt.Errorf("stream logs: %w", err)
	}
	defer stream.Close()

	bts, err := io.ReadAll(stream)
	if err != nil {
		return fmt.Errorf("read logs: %w", err)
	}
	out := string(bts)

	if !strings.Contains(out, "0% packet loss") {
		return fmt.Errorf("non-zero packet loss, logs:\n%s", out)
	}

	return nil
}

func TestApplyAndDestroy(t *testing.T) {
	t.Parallel()
	// Generate unique prefix. K8s resources names cannot start with a number
	testNamePrefix := fmt.Sprintf("test-%s", strings.ToLower(random.UniqueId()))

	// Copy code and tfvars
	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
	if err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars")); err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	// Configure Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		MixedVars: []terraform.Var{
			terraform.VarFile("test.tfvars"),
			terraform.VarInline("name_prefix", testNamePrefix),
		},
		NoColor: true,
	})

	defer helper.TerraformDestroyVpcWithMembers(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Create an EC2 client and verify that the VPN comes up
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		t.Fatalf("unable to load AWS config: %v", err)
	}
	ec2Client := ec2.NewFromConfig(cfg)
	verifyVpnUp(t, context.Background(), ec2Client, testNamePrefix)
}
