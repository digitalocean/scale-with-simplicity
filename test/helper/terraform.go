package helper

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"strings"
	"testing"
	"time"
)

func TerraformDestroyVpcWithMembers(t *testing.T, terraformOptions *terraform.Options) {
	t.Log("Starting Terraform destroy...")

	if _, err := terraform.DestroyE(t, terraformOptions); err != nil {
		if strings.Contains(err.Error(), "Can not delete VPC with members") {
			t.Logf("VPC not ready to delete, retrying after delay...")
			time.Sleep(60 * time.Second)

			// Retry with fatal failure if it still doesn't work
			terraform.Destroy(t, terraformOptions)
		} else {
			t.Fatalf("Failed to destroy resources: %v", err)
		}
	}
}
