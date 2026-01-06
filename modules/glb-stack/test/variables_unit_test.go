package test

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"testing"
)

func baseTerraformVars() map[string]interface{} {
	return map[string]interface{}{
		"name_prefix": "test",
		"vpcs": []map[string]string{
			{
				"region":   "nyc3",
				"vpc_uuid": "1234",
			},
		},
		"regional_lb_config": map[string]interface{}{
			"type": "REGIONAL",
		},
		"global_lb_config": map[string]interface{}{
			"domains": []interface{}{
				map[string]interface{}{
					"name":       "test.do.com",
					"is_managed": true,
				},
			},
			"type": "GLOBAL",
		},
	}
}

func TestErrorIfEmptyVpcConfig(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	tfVars := baseTerraformVars()
	tfVars["vpcs"] = []map[string]string{}
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars:         tfVars,
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	_, err := terraform.InitAndPlanAndShowWithStructE(t, terraformOptions)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "at least one")
}

func TestErrorIfRlbSetsTypeGlobal(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	tfVars := baseTerraformVars()
	tfVars["regional_lb_config"].(map[string]interface{})["type"] = "GLOBAL"
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars:         tfVars,
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	_, err := terraform.InitAndPlanAndShowWithStructE(t, terraformOptions)
	require.Error(t, err)
	assert.Contains(t, err.Error(), `must be either "REGIONAL"`)
}

func TestErrorIfGlbSetsTypeNotGlobal(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	tfVars := baseTerraformVars()
	tfVars["global_lb_config"].(map[string]interface{})["type"] = "REGIONAL"
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars:         tfVars,
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	_, err := terraform.InitAndPlanAndShowWithStructE(t, terraformOptions)
	require.Error(t, err)
	assert.Contains(t, err.Error(), `must be "GLOBAL"`)
}

func TestErrorIfGlbSetsMoreThanOneDomain(t *testing.T) {
	t.Parallel()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	tfVars := baseTerraformVars()
	tfVars["global_lb_config"].(map[string]interface{})["domains"] = []interface{}{
		map[string]interface{}{
			"name":       "test.do.com",
			"is_managed": true,
		},
		map[string]interface{}{
			"name":       "test2.do.com",
			"is_managed": true,
		},
	}
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars:         tfVars,
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	_, err := terraform.InitAndPlanAndShowWithStructE(t, terraformOptions)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "contain exactly one")
}
