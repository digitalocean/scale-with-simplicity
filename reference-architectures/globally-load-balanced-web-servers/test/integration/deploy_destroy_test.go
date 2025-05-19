package integration

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/files"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"path/filepath"

	"strings"
	"testing"
	"time"
)

func TestDeployAndDestroy(t *testing.T) {
	t.Parallel()
	testNamePrefix := random.UniqueId()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		MixedVars:    []terraform.Var{terraform.VarFile("test.tfvars"), terraform.VarInline("name_prefix", testNamePrefix)},
		NoColor:      true,
	})
	defer func() {
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
	}()

	terraform.InitAndApply(t, terraformOptions)

	glbFqdn := terraform.Output(t, terraformOptions, "glb_fqdn")
	rlbFqdns := terraform.OutputList(t, terraformOptions, "rlb_fqdns")
	urls := []string{
		fmt.Sprintf("http://%s", glbFqdn),
	}
	for _, fqdns := range rlbFqdns {
		urls = append(urls, fmt.Sprintf("http://%s", fqdns))
	}

	// give time for everything to come up
	time.Sleep(30 * time.Second)
	validateResponse := func(statusCode int, body string) bool {
		return statusCode == 200 && strings.Contains(body, "Region:")
	}

	maxRetries := 12
	timeBetweenRetries := 5 * time.Second

	for _, url := range urls {
		http_helper.HttpGetWithRetryWithCustomValidation(
			t,
			url,
			nil,
			maxRetries,
			timeBetweenRetries,
			validateResponse,
		)
	}
}
