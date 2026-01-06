package test

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGlBCreationWithoutNameInConfig(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", "./modules/global_loadbalancer")

	targetIds := []interface{}{"test1", "test2"}
	domainsConfig := []interface{}{
		map[string]interface{}{
			"name":       "test.do.com",
			"is_managed": true,
		},
	}
	glbSettings := map[string]interface{}{
		"target_protocol": "https",
		"target_port":     443,
	}
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name_prefix":              "test",
			"target_load_balancer_ids": targetIds,
			"glb_config": map[string]interface{}{
				"domains":      domainsConfig,
				"glb_settings": glbSettings,
			},
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	glbConfig := plan.ResourcePlannedValuesMap["digitalocean_loadbalancer.this"]
	glbConfigSettings := glbConfig.AttributeValues["glb_settings"].([]interface{})[0].(map[string]interface{})

	assert.Equal(t, "test-glb", glbConfig.AttributeValues["name"])
	assert.Equal(t, targetIds, glbConfig.AttributeValues["target_load_balancer_ids"])
	assert.Equal(t, domainsConfig, glbConfig.AttributeValues["domains"])
	assert.Equal(t, glbSettings["target_protocol"], glbConfigSettings["target_protocol"])
}

func TestGlBCreationWithNameInConfig(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", "./modules/global_loadbalancer")

	targetIds := []interface{}{"test1", "test2"}
	domainsConfig := []interface{}{
		map[string]interface{}{
			"name":       "test.do.com",
			"is_managed": true,
		},
	}
	glbSettings := map[string]interface{}{
		"target_protocol": "https",
		"target_port":     443,
	}
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name_prefix":              "test",
			"target_load_balancer_ids": targetIds,
			"glb_config": map[string]interface{}{
				"name":         "www-test-glb",
				"domains":      domainsConfig,
				"glb_settings": glbSettings,
			},
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	glbConfig := plan.ResourcePlannedValuesMap["digitalocean_loadbalancer.this"]
	assert.Equal(t, "www-test-glb", glbConfig.AttributeValues["name"])
}
