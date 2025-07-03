package unit

import (
	"github.com/gruntwork-io/terratest/modules/files"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestPlanWithHa(t *testing.T) {
	t.Parallel()

	accessKey := os.Getenv("MEGAPORT_ACCESS_KEY")
	secretKey := os.Getenv("MEGAPORT_SECRET_KEY")

	if accessKey == "" || secretKey == "" {
		t.Skip("Skipping test: MEGAPORT_ACCESS_KEY and MEGAPORT_SECRET_KEY must be set to run this test")
	}

	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		MixedVars:    []terraform.Var{terraform.VarFile("test.tfvars")},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	pncCount := 0
	for _, v := range plan.ResourcePlannedValuesMap {
		if v.Type == "digitalocean_partner_attachment" {
			pncCount += 1
		}
	}
	assert.Equal(t, 2, pncCount)
}

func TestPlanWithoutHa(t *testing.T) {
	t.Parallel()

	accessKey := os.Getenv("MEGAPORT_ACCESS_KEY")
	secretKey := os.Getenv("MEGAPORT_SECRET_KEY")

	if accessKey == "" || secretKey == "" {
		t.Skip("Skipping test: MEGAPORT_ACCESS_KEY and MEGAPORT_SECRET_KEY must be set to run this test")
	}

	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		MixedVars:    []terraform.Var{terraform.VarFile("test.tfvars"), terraform.VarInline("ha_enabled", false)},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	pncCount := 0
	for _, v := range plan.ResourcePlannedValuesMap {
		if v.Type == "digitalocean_partner_attachment" {
			pncCount += 1
		}
	}
	assert.Equal(t, 1, pncCount)
}
