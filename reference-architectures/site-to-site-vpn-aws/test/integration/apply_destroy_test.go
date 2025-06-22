package integration

import (
	"fmt"
	"github.com/digitalocean/scale-with-simplicity/test/helper"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"path/filepath"

	"strings"
	"testing"
)

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
}
