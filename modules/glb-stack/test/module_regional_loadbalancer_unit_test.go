package test

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRlBCreation(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", "./modules/regional_loadbalancer")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name":     "test-name",
			"region":   "nyc3",
			"vpc_uuid": "1234",
			"lb_config": map[string]interface{}{
				"forwarding_rule": map[string]interface{}{
					"entry_port":      443,
					"entry_protocol":  "https",
					"target_port":     80,
					"target_protocol": "http",
				},
			},
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	rlbConfig := plan.ResourcePlannedValuesMap["digitalocean_loadbalancer.this"]
	rlbConfigForwardingRule := rlbConfig.AttributeValues["forwarding_rule"].([]interface{})[0].(map[string]interface{})
	assert.Equal(t, "test-name", rlbConfig.AttributeValues["name"])
	assert.Equal(t, "nyc3", rlbConfig.AttributeValues["region"])
	assert.Equal(t, "1234", rlbConfig.AttributeValues["vpc_uuid"])
	assert.Equal(t, "https", rlbConfigForwardingRule["entry_protocol"])
}
