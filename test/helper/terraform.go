package helper

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"strings"
	"testing"
	"time"
)

func TerraformDestroyVpcWithMembers(t *testing.T, terraformOptions *terraform.Options) {
	const (
		maxRetries = 5
		retryDelay = 30 * time.Second
	)

	t.Log("Starting Terraform destroy...")

	for attempt := 1; attempt <= maxRetries; attempt++ {
		t.Logf("Destroy attempt %d/%d", attempt, maxRetries)
		_, err := terraform.DestroyE(t, terraformOptions)
		if err == nil {
			t.Log("Terraform destroy succeeded")
			return
		}

		// Check for the VPC-with-members error
		if strings.Contains(err.Error(), "Can not delete VPC with members") {
			if attempt < maxRetries {
				t.Logf("VPC still has members, retrying in %v...", retryDelay)
				time.Sleep(retryDelay)
				continue
			}
			// last attempt and still failing
			t.Fatalf("VPC still has members after %d attempts: %v", maxRetries, err)
		}

		// any other error should stop immediately
		t.Fatalf("Failed to destroy resources: %v", err)
	}
}
