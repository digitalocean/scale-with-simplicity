package test

import (
	"github.com/gruntwork-io/terratest/modules/random"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestPnCCreation(t *testing.T) {
	t.Parallel()
	accessKey := os.Getenv("MEGAPORT_ACCESS_KEY")
	secretKey := os.Getenv("MEGAPORT_SECRET_KEY")

	if accessKey == "" || secretKey == "" {
		t.Skip("Skipping test: MEGAPORT_ACCESS_KEY and MEGAPORT_SECRET_KEY must be set to run this test")
	}

	uniqueId := random.UniqueId()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")

	// Inject the required provider block
	providerContent := `
provider "megaport" {
  environment           = "production"
  accept_purchase_terms = true
}
`
	providerFile := filepath.Join(testDir, "providers.tf")
	if err := os.WriteFile(providerFile, []byte(providerContent), 0644); err != nil {
		t.Fatalf("Failed to write providers.tf: %v", err)
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name_prefix":                uniqueId,
			"do_region":                  "sfo",
			"mp_contract_term_months":    1,
			"mcr_port_bandwidth_in_mbps": 1000,
			"vxc_bandwidth_in_mbps":      1000,
			"mp_do_location":             "Digital Realty New York JFK12 (NYC1)",
			"mp_aws_location":            "CoreSite NY1",
			"aws_region_full_name":       "US East (N. Virginia) (us-east-1)",
			"aws_vgw_id":                 "vgw-test123",
			"do_vpc_ids":                 []string{"test123"},
			"bgp_password":               "test123",
			"diversity_zone":             "red",
			"do_local_router_ip":         "169.254.0.1/29",
			"do_peer_router_ip":          "169.254.0.6/29",
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	terraform.InitAndPlan(t, terraformOptions)
}
