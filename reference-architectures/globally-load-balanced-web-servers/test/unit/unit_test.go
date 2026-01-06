package unit

import (
	"github.com/gruntwork-io/terratest/modules/files"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestCreateMultipleDroplets(t *testing.T) {
	t.Parallel()
	// Copy from repo root to preserve relative module paths (../../../modules)
	testDir := test_structure.CopyTerraformFolderToTemp(t, "../../../..", ".")
	terraformDir := filepath.Join(testDir, "reference-architectures/globally-load-balanced-web-servers/terraform")
	err := files.CopyFile("../test.tfvars", filepath.Join(terraformDir, "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDir,
		MixedVars:    []terraform.Var{terraform.VarInline("droplet_count", 2), terraform.VarFile("test.tfvars")},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	dropletCount := 0
	for _, v := range plan.ResourcePlannedValuesMap {
		if v.Type == "digitalocean_droplet" {
			dropletCount += 1
		}
	}
	assert.Equal(t, 6, dropletCount)
}
