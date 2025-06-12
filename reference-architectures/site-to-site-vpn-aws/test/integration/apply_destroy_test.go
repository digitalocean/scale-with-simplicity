package integration

import (
	"fmt"
	"github.com/digitalocean/scale-with-simplicity/test/constant"
	"github.com/digitalocean/scale-with-simplicity/test/helper"
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

func TestApplyAndDestroy(t *testing.T) {
	t.Parallel()
	testNamePrefix := strings.ToLower(random.UniqueId())
	testDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "./terraform")
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	client := helper.CreateGodoClient()
	testDomainFqdn := helper.CreateTestDomain(client, constant.TestRootSubdomain, testNamePrefix)
	sshKey := helper.CreateSshKey(client, testNamePrefix)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		MixedVars: []terraform.Var{
			terraform.VarFile("test.tfvars"),
			terraform.VarInline("name_prefix", testNamePrefix),
			terraform.VarInline("domain", testDomainFqdn),
			terraform.VarInline("ssh_key", sshKey.Name)},
		NoColor: true,
	})
	defer helper.TerraformDestroyVpcWithMembers(t, terraformOptions)
	defer helper.DeleteTestDomain(client, constant.TestRootSubdomain, testNamePrefix)
	//defer helper.DeleteSshKey(client, sshKey.ID)

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
