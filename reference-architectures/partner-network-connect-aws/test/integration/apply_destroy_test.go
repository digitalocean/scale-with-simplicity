package integration

import (
	"context"
	"fmt"
	"github.com/digitalocean/godo"
	"github.com/digitalocean/scale-with-simplicity/test/helper"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"log"
	"os"
	"path/filepath"

	"strings"
	"testing"
	"time"
)

// validateRoute returns true if the given cidr is present in the list of
// remote routes for the specified Partner Attachment ID.
func validateRoute(client *godo.Client, pncAttachmentId, cidr string) bool {
	ctx := context.Background()
	opt := &godo.ListOptions{}

	for {
		routes, resp, err := client.PartnerAttachment.ListRoutes(ctx, pncAttachmentId, opt)
		if err != nil {
			log.Printf("error listing routes for attachment %s: %v", pncAttachmentId, err)
			return false
		}

		for _, r := range routes {
			if r.Cidr == cidr {
				return true
			}
		}

		// no more pages
		if resp.Links == nil || resp.Links.IsLastPage() {
			break
		}

		page, err := resp.Links.CurrentPage()
		if err != nil {
			log.Printf("error getting current page for attachment %s: %v", pncAttachmentId, err)
			return false
		}
		opt.Page = page + 1
	}

	return false
}

func TestValidateRoute(t *testing.T) {
	client := helper.CreateGodoClient()
	assert.Equal(t, true, validateRoute(client, "31c51cd7-6914-4e37-b952-3ef6c8888fc3", "192.168.1.0/24"))
}

func TestApplyAndDestroy(t *testing.T) {
	t.Parallel()

	accessKey := os.Getenv("MEGAPORT_ACCESS_KEY")
	secretKey := os.Getenv("MEGAPORT_SECRET_KEY")

	if accessKey == "" || secretKey == "" {
		t.Skip("Skipping test: MEGAPORT_ACCESS_KEY and MEGAPORT_SECRET_KEY must be set to run this test")
	}

	// Generate unique prefix. K8s resources names cannot start with a number
	testNamePrefix := fmt.Sprintf("test-%s", strings.ToLower(random.UniqueId()))

	// Copy from repo root to preserve relative module paths (../../../modules/)
	tempRoot := test_structure.CopyTerraformFolderToTemp(t, "../../../..", ".")
	testDir := filepath.Join(tempRoot, "reference-architectures", "partner-network-connect-aws", "terraform")
	err := files.CopyFile("../test.tfvars", filepath.Join(testDir, "test.tfvars"))
	if err != nil {
		t.Fatalf("Failed to copy tfvars file: %v", err)
	}

	client := helper.CreateGodoClient()
	awsVpcCidr := "192.168.0.0/24"
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		MixedVars: []terraform.Var{
			terraform.VarFile("test.tfvars"),
			terraform.VarInline("name_prefix", testNamePrefix),
			terraform.VarInline("aws_vpc_cidr", awsVpcCidr),
		},
		NoColor: true,
	})
	terraform.InitAndApply(t, terraformOptions)
	defer helper.TerraformDestroyVpcWithMembers(t, terraformOptions)

	maxRetries := 15
	timeBetweenRetries := 1 * time.Minute
	pncAttachmentId := terraform.Output(t, terraformOptions, "partner_attachment_uuid_red")

	for i := 0; i < maxRetries; i++ {
		if validateRoute(client, pncAttachmentId, awsVpcCidr) {
			t.Logf("Route %s found on attempt %d", awsVpcCidr, i+1)
			return // test passed
		}

		if i < maxRetries-1 {
			t.Logf("Route %s not found on attempt %d, retrying in %s...", awsVpcCidr, i+1, timeBetweenRetries)
			time.Sleep(timeBetweenRetries)
		}
	}

	t.Fatalf("Route %s not found after %d attempts", awsVpcCidr, maxRetries)
}
