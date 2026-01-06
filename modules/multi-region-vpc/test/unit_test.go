package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/random"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestVpcCreation(t *testing.T) {
	t.Parallel()
	uniqueId := random.UniqueId()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name_prefix": uniqueId,
			"vpcs": []map[string]interface{}{
				{
					"region":   "nyc3",
					"ip_range": "10.0.0.0/16",
				},
				{
					"region":   "sfo3",
					"ip_range": "10.1.0.0/16",
				},
				{
					"region":   "ams3",
					"ip_range": "10.2.0.0/16",
				},
			},
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	nyc3_vpc := plan.ResourcePlannedValuesMap["digitalocean_vpc.vpc[\"vpc-0\"]"]
	assert.Equal(t, fmt.Sprintf("%s-nyc3", uniqueId), nyc3_vpc.AttributeValues["name"])
	assert.Equal(t, "10.0.0.0/16", nyc3_vpc.AttributeValues["ip_range"])
	sfo3_vpc := plan.ResourcePlannedValuesMap["digitalocean_vpc.vpc[\"vpc-1\"]"]
	assert.Equal(t, fmt.Sprintf("%s-sfo3", uniqueId), sfo3_vpc.AttributeValues["name"])
	assert.Equal(t, "10.1.0.0/16", sfo3_vpc.AttributeValues["ip_range"])
	ams3_vpc := plan.ResourcePlannedValuesMap["digitalocean_vpc.vpc[\"vpc-2\"]"]
	assert.Equal(t, fmt.Sprintf("%s-ams3", uniqueId), ams3_vpc.AttributeValues["name"])
	assert.Equal(t, "10.2.0.0/16", ams3_vpc.AttributeValues["ip_range"])
}

func TestVpcPeeringCreate(t *testing.T) {
	t.Parallel()
	uniqueId := random.UniqueId()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name_prefix": uniqueId,
			"vpcs": []map[string]interface{}{
				{
					"region":   "nyc3",
					"ip_range": "10.0.0.0/16",
				},
				{
					"region":   "sfo3",
					"ip_range": "10.1.0.0/16",
				},
				{
					"region":   "ams3",
					"ip_range": "10.2.0.0/16",
				},
				{
					"region":   "syd1",
					"ip_range": "10.3.0.0/16",
				},
			},
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	vpc_peering_count := 0
	for _, v := range plan.ResourcePlannedValuesMap {
		if v.Type == "digitalocean_vpc_peering" {
			vpc_peering_count += 1
		}
	}
	assert.Equal(t, 6, vpc_peering_count)
}

func TestFailIfNoVpcInput(t *testing.T) {
	t.Parallel()
	uniqueId := random.UniqueId()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name_prefix": uniqueId,
			"vpcs":        []map[string]interface{}{},
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	_, err := terraform.InitAndPlanAndShowWithStructE(t, terraformOptions)
	require.Error(t, err)
}
