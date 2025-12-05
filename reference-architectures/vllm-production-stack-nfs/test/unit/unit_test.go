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

// Note: Integration tests are skipped for this RA because they require:
// - H100 GPU quota in NYC2 region
// - Managed NFS availability
// The infrastructure can be tested manually with appropriate quota.
