package unit

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestPlanInfra(t *testing.T) {
	t.Parallel()

	// Copy code to temp dir and init
	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform/1-infra")
	// Copy test.tfvars into temp dir
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	// Configure Terraform options with inline override
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		MixedVars:    []terraform.Var{terraform.VarFile("test.tfvars")},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})

	// Run `terraform init` and `terraform plan`; test fails if errors occur
	terraform.InitAndPlanAndShow(t, terraformOptions)
}

// Note: We cannot unit test the 2-cluster or 3-environment stacks because they require:
// 1. A real DOKS cluster to exist (for the kubernetes/helm providers)
// 2. Resources from the 1-infra stack (databases, Spaces bucket, etc.)
// These stacks will be tested as part of the integration tests.
