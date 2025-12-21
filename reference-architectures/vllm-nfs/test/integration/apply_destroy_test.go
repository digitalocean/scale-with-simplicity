package integration

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

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

	// Get HuggingFace token from environment (optional for public models like Qwen)
	hfToken := os.Getenv("HF_TOKEN")

	// Create API client and CIDR assigner
	ctx := context.Background()
	client := helper.CreateGodoClient()
	cidrAssigner := helper.NewCidrAssigner(ctx, client)

	// Allocate non-overlapping CIDR blocks
	vpcCidr := cidrAssigner.GetVpcCidr()
	clusterCidr := cidrAssigner.GetDoksClusterCidr()
	serviceCidr := cidrAssigner.GetDoksServiceCidr()
	logger.Logf(t, "Allocated VPC CIDR: %s, Cluster CIDR: %s, Service CIDR: %s", vpcCidr, clusterCidr, serviceCidr)

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
			terraform.VarInline("gpu_node_count", 1), // Minimum for test
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
	logger.Logf(t, "Stack 1 outputs - Cluster: %s", clusterName)

	// Configure Terraform options for Stack 2 (vLLM)
	// Only pass hf_token if it's set (optional for public models like Qwen)
	stack2Vars := []terraform.Var{}
	if hfToken != "" {
		stack2Vars = append(stack2Vars, terraform.VarInline("hf_token", hfToken))
	}
	stack2Options := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: filepath.Join(testDir, "2-vllm"),
		MixedVars:    stack2Vars,
		NoColor:      true,
	})

	// Apply Stack 2 (vLLM deployment)
	// Note: This includes model download which can take up to several minutes
	logger.Log(t, "Applying Stack 2 (vLLM deployment)...")
	// We don't destroy this stack as its just K8s resources and we don't need to worry about TF State after the test.
	terraform.InitAndApply(t, stack2Options)

	// Write kubeconfig to temp file for kubectl access
	kubeconfigPath := filepath.Join(testDir, "kubeconfig.yaml")

	// Configure kubectl using the cluster endpoint and credentials from Stack 1
	logger.Log(t, "Configuring kubectl access to cluster...")
	kubectlOptions := helper.ConfigureKubectl(t, client, clusterName, kubeconfigPath, "vllm")

	// Wait for vLLM to be ready and get Gateway IP
	logger.Log(t, "Waiting for vLLM Gateway to get external IP...")
	gatewayIP := waitForGatewayIP(t, kubectlOptions)
	logger.Logf(t, "Gateway IP: %s", gatewayIP)

	// Wait for vLLM pods to be ready
	logger.Log(t, "Waiting for vLLM pods to be ready...")
	waitForVLLMReady(t, kubectlOptions)

	// Verify inference endpoint
	logger.Log(t, "Verifying inference endpoint...")
	verifyInference(t, kubectlOptions, gatewayIP)

	logger.Log(t, "All validations passed!")
}

// waitForGatewayIP waits for the Gateway to get an external IP address
func waitForGatewayIP(t *testing.T, kubectlOptions *k8s.KubectlOptions) string {
	maxRetries := 30
	timeBetweenRetries := 30 * time.Second

	description := "Waiting for Gateway to get external IP"
	gatewayIP, err := retry.DoWithRetryE(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		// Use kubectl to get the gateway status
		output, err := k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "get", "gateway", "vllm-gateway", "-o", "jsonpath={.status.addresses[0].value}")
		if err != nil {
			return "", fmt.Errorf("failed to get gateway: %v", err)
		}

		ip := strings.TrimSpace(output)
		if ip == "" {
			return "", fmt.Errorf("gateway IP not yet assigned")
		}

		return ip, nil
	})

	if err != nil {
		t.Fatalf("Gateway did not get external IP: %v", err)
	}

	return gatewayIP
}

// waitForVLLMReady waits for vLLM deployment pods to be ready
func waitForVLLMReady(t *testing.T, kubectlOptions *k8s.KubectlOptions) {
	maxRetries := 60 // vLLM model loading can take a while
	timeBetweenRetries := 30 * time.Second

	description := "Waiting for vLLM pods to be ready"
	_, err := retry.DoWithRetryE(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		// Check if deployment has available replicas
		output, err := k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "get", "deployment", "vllm", "-o", "jsonpath={.status.availableReplicas}")
		if err != nil {
			return "", fmt.Errorf("failed to get deployment status: %v", err)
		}

		availableReplicas := strings.TrimSpace(output)
		if availableReplicas == "" || availableReplicas == "0" {
			// Get pod status for debugging
			podStatus, _ := k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "get", "pods", "-l", "app=vllm", "-o", "wide")
			logger.Logf(t, "vLLM pods status:\n%s", podStatus)
			return "", fmt.Errorf("vLLM pods not yet ready (available: %s)", availableReplicas)
		}

		return availableReplicas, nil
	})

	if err != nil {
		t.Fatalf("vLLM pods did not become ready: %v", err)
	}
}

// verifyInference makes an inference call to the vLLM endpoint and validates the response
func verifyInference(t *testing.T, kubectlOptions *k8s.KubectlOptions, gatewayIP string) {
	// Build the curl command for inference using the default model (Qwen2.5-0.5B-Instruct)
	curlCmd := fmt.Sprintf(`curl -s -X POST http://%s/v1/chat/completions \
		-H "Content-Type: application/json" \
		-d '{"model":"Qwen2.5-0.5B-Instruct","messages":[{"role":"user","content":"Say hello in one word"}],"max_tokens":10}'`, gatewayIP)

	// Run inference via a curl pod to ensure network connectivity from within the cluster
	result, err := helper.RunPod(t, kubectlOptions, helper.PodRunOptions{
		Name:           "test-inference",
		Image:          "curlimages/curl:latest",
		Command:        []string{"sh", "-c", curlCmd},
		MaxWaitSeconds: 180, // Inference can take time on first request
	})
	if err != nil {
		t.Fatalf("Failed to run inference test pod: %v", err)
	}

	// Log the response
	logger.Logf(t, "Inference response:\n%s", result.Logs)

	// Parse the response to validate it contains expected fields
	var response map[string]interface{}
	if err := json.Unmarshal([]byte(result.Logs), &response); err != nil {
		t.Fatalf("Failed to parse inference response as JSON: %v\nResponse: %s", err, result.Logs)
	}

	// Check for required fields in OpenAI-compatible response
	if _, ok := response["choices"]; !ok {
		t.Errorf("Inference response missing 'choices' field: %s", result.Logs)
	}

	if _, ok := response["model"]; !ok {
		t.Errorf("Inference response missing 'model' field: %s", result.Logs)
	}

	// Validate we got at least one choice with content
	choices, ok := response["choices"].([]interface{})
	if !ok || len(choices) == 0 {
		t.Errorf("Inference response has no choices: %s", result.Logs)
		return
	}

	choice := choices[0].(map[string]interface{})
	message, ok := choice["message"].(map[string]interface{})
	if !ok {
		t.Errorf("Inference response choice missing message: %s", result.Logs)
		return
	}

	content, ok := message["content"].(string)
	if !ok || content == "" {
		t.Errorf("Inference response message has no content: %s", result.Logs)
		return
	}

	logger.Logf(t, "Inference successful! Model response: %s", content)
}
