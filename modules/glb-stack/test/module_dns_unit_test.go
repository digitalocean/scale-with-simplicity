package test

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDnsRecordCreate(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", "./modules/dns")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"domain": "test.do.com",
			"region_lbs": []map[string]interface{}{
				{
					"ip":     "10.0.0.1",
					"region": "nyc3",
				},
				{
					"ip":     "10.1.0.1",
					"region": "ams3",
				},
			},
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	nyc3Dns := plan.ResourcePlannedValuesMap["digitalocean_record.regional_fqdn[\"nyc3\"]"]
	assert.Equal(t, "10.0.0.1", nyc3Dns.AttributeValues["value"])
	dnsCount := 0
	for _, v := range plan.ResourcePlannedValuesMap {
		if v.Type == "digitalocean_record" {
			dnsCount += 1
		}
	}
	assert.Equal(t, 2, dnsCount)
}
