package integration

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/digitalocean/godo"
	"github.com/digitalocean/scale-with-simplicity/test/constant"
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

	// Get DigitalOcean access token from environment (required for Stack 2)
	doToken := os.Getenv("DIGITALOCEAN_ACCESS_TOKEN")
	if doToken == "" {
		t.Fatal("DIGITALOCEAN_ACCESS_TOKEN environment variable is required")
	}

	// Create API client and CIDR assigner
	ctx := context.Background()
	client := helper.CreateGodoClient()
	cidrAssigner := helper.NewCidrAssigner(ctx, client)

	// Allocate non-overlapping CIDR blocks
	vpcCidr := cidrAssigner.GetVpcCidr()
	clusterCidr := cidrAssigner.GetDoksClusterCidr()
	serviceCidr := cidrAssigner.GetDoksServiceCidr()
	logger.Logf(t, "Allocated VPC CIDR: %s, Cluster CIDR: %s, Service CIDR: %s", vpcCidr, clusterCidr, serviceCidr)

	// Create test domain for demo app (fqdn) and log sink (log_sink_fqdn)
	testDomainFqdn := helper.CreateTestDomain(client, constant.TestRootSubdomain, testNamePrefix)
	defer helper.DeleteTestDomain(client, constant.TestRootSubdomain, testNamePrefix)
	logger.Logf(t, "Created test domain: %s", testDomainFqdn)

	// Build FQDNs for the demo app and log sink
	demoFqdn := fmt.Sprintf("demo.%s", testDomainFqdn)
	logSinkFqdn := fmt.Sprintf("logs.%s", testDomainFqdn)
	logger.Logf(t, "Demo FQDN: %s, Log Sink FQDN: %s", demoFqdn, logSinkFqdn)

	// Copy entire terraform directory to preserve relative path structure
	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
	logger.Logf(t, "Copied terraform directory to: %s", testDir)

	// Copy test.tfvars for Stack 1
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "1-infra", "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars: %v", err)
	}

	// ==================== Stack 1: Infrastructure ====================
	stack1Options := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(testDir, "1-infra"),
		MixedVars: []terraform.Var{
			terraform.VarFile("test.tfvars"),
			terraform.VarInline("name_prefix", testNamePrefix),
			terraform.VarInline("vpc_cidr", vpcCidr),
			terraform.VarInline("doks_cluster_subnet", clusterCidr),
			terraform.VarInline("doks_service_subnet", serviceCidr),
		},
		NoColor: true,
	})

	// Ensure cleanup happens in correct order (Stack 1 last)
	defer helper.TerraformDestroyVpcWithMembers(t, stack1Options)

	logger.Log(t, "Applying Stack 1 (infrastructure)...")
	terraform.InitAndApply(t, stack1Options)
	logger.Log(t, "Stack 1 applied successfully")

	// ==================== Stack 2: Cluster Services ====================
	stack2Options := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(testDir, "2-cluster"),
		MixedVars: []terraform.Var{
			terraform.VarInline("name_prefix", testNamePrefix),
			terraform.VarInline("digitalocean_access_token", doToken),
			terraform.VarInline("log_sink_fqdn", logSinkFqdn),
		},
		NoColor: true,
	})

	// Ensure Stack 2 is destroyed before Stack 1
	defer terraform.Destroy(t, stack2Options)

	logger.Log(t, "Applying Stack 2 (cluster services)...")
	terraform.InitAndApply(t, stack2Options)
	logger.Log(t, "Stack 2 applied successfully")

	// ==================== Stack 3: Environment ====================
	stack3Options := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(testDir, "3-environment"),
		MixedVars: []terraform.Var{
			terraform.VarInline("name_prefix", testNamePrefix),
			terraform.VarInline("fqdn", demoFqdn),
			terraform.VarInline("log_sink_fqdn", logSinkFqdn),
		},
		NoColor: true,
	})

	// Ensure Stack 3 is destroyed before Stack 2
	defer terraform.Destroy(t, stack3Options)

	logger.Log(t, "Applying Stack 3 (environment)...")
	terraform.InitAndApply(t, stack3Options)
	logger.Log(t, "Stack 3 applied successfully")

	// ==================== Observability Validation ====================
	logger.Log(t, "Waiting for observability components to stabilize...")
	time.Sleep(60 * time.Second)

	// Configure kubectl for validation
	kubeconfigPath := filepath.Join(testDir, "kubeconfig.yaml")
	kubectlOptions := helper.ConfigureKubectl(t, client, testNamePrefix, kubeconfigPath, "default")

	// Validate PostgreSQL metrics in Prometheus
	logger.Log(t, "Validating PostgreSQL metrics in Prometheus...")
	verifyPrometheusMetric(t, kubectlOptions, "pg_up", "PostgreSQL exporter")

	// Validate Redis/Valkey metrics in Prometheus
	logger.Log(t, "Validating Redis/Valkey metrics in Prometheus...")
	verifyPrometheusMetric(t, kubectlOptions, "redis_up", "Redis exporter")

	// Validate database logs in Loki
	logger.Log(t, "Validating database logs in Loki...")
	verifyLokiLogs(t, kubectlOptions)

	logger.Log(t, "All observability validations passed!")
}

// verifyPrometheusMetric queries Prometheus for a specific metric and verifies it equals 1
func verifyPrometheusMetric(t *testing.T, kubectlOptions *k8s.KubectlOptions, metricName string, description string) {
	maxRetries := 12
	timeBetweenRetries := 10 * time.Second

	_, err := retry.DoWithRetryE(t, fmt.Sprintf("Checking %s metric: %s", description, metricName), maxRetries, timeBetweenRetries, func() (string, error) {
		// Run a curl pod to query Prometheus
		result, err := helper.RunPod(t, kubectlOptions, helper.PodRunOptions{
			Name:      fmt.Sprintf("test-prometheus-%s", strings.ToLower(random.UniqueId())),
			Namespace: "default",
			Image:     "curlimages/curl:latest",
			Command: []string{"sh", "-c", fmt.Sprintf(`
				response=$(curl -sf 'http://kube-prometheus-stack-prometheus.cluster-services:9090/api/v1/query?query=%s')
				echo "$response"
				# Check if we got a result with value "1"
				echo "$response" | grep -q '"value":\[.*,"1"\]'
			`, metricName)},
			MaxWaitSeconds: 60,
		})
		if err != nil {
			return "", fmt.Errorf("prometheus query failed: %v", err)
		}

		logger.Logf(t, "Prometheus response for %s: %s", metricName, result.Logs)
		return result.Logs, nil
	})

	if err != nil {
		t.Errorf("Failed to verify %s metric %s: %v", description, metricName, err)
	} else {
		logger.Logf(t, "✓ %s metric %s is reporting correctly", description, metricName)
	}
}

// verifyLokiLogs queries Loki for database logs and verifies they are being collected
func verifyLokiLogs(t *testing.T, kubectlOptions *k8s.KubectlOptions) {
	maxRetries := 18 // Longer timeout for logs - rsyslog may take time to send initial logs
	timeBetweenRetries := 10 * time.Second

	_, err := retry.DoWithRetryE(t, "Checking database logs in Loki", maxRetries, timeBetweenRetries, func() (string, error) {
		// Run a curl pod to query Loki
		// Query for database logs using the job label set by Alloy
		result, err := helper.RunPod(t, kubectlOptions, helper.PodRunOptions{
			Name:      fmt.Sprintf("test-loki-%s", strings.ToLower(random.UniqueId())),
			Namespace: "default",
			Image:     "curlimages/curl:latest",
			Command: []string{"sh", "-c", `
				# Get current time and 1 hour ago in nanoseconds
				end=$(date +%s)000000000
				start=$((end - 3600000000000))

				response=$(curl -sf "http://loki-gateway.cluster-services/loki/api/v1/query_range?query=%7Bjob%3D%22database-logs%22%7D&start=${start}&end=${end}&limit=10")
				echo "$response"

				# Check if we got any results (result array is not empty)
				echo "$response" | grep -q '"result":\[{'
			`},
			MaxWaitSeconds: 60,
		})
		if err != nil {
			return "", fmt.Errorf("loki query failed: %v", err)
		}

		logger.Logf(t, "Loki response: %s", result.Logs)
		return result.Logs, nil
	})

	if err != nil {
		t.Errorf("Failed to verify database logs in Loki: %v", err)
	} else {
		logger.Logf(t, "✓ Database logs are being collected in Loki")
	}
}

// configureKubectl is a local wrapper that's kept for backward compatibility
// It uses the shared helper.ConfigureKubectl function
func configureKubectl(t *testing.T, client *godo.Client, clusterName string, kubeconfigPath string) *k8s.KubectlOptions {
	return helper.ConfigureKubectl(t, client, clusterName, kubeconfigPath, "default")
}
