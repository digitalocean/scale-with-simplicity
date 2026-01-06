package test

import (
	"github.com/gruntwork-io/terratest/modules/random"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestDropletCreate(t *testing.T) {
	t.Parallel()
	uniqueId := random.UniqueId()
	testDir := test_structure.CopyTerraformFolderToTemp(t, "..", ".")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		Vars: map[string]interface{}{
			"name":                 uniqueId,
			"region":               "nyc3",
			"size":                 "s-1vcpu-1gb",
			"image":                "ubuntu-24-10-x64",
			"vpc_id":               "50b00b45-0f90-40dc-ac95-60e0d09f9f58",
			"vpn_psk":              "secret_string",
			"do_vpn_public_ip":     "1.1.1.1",
			"do_vpn_tunnel_ip":     "169.254.104.102",
			"remote_vpn_public_ip": "2.2.2.2",
			"remote_vpn_tunnel_ip": "169.254.104.101",
			"remote_vpn_cidr":      "192.168.0.0/24",
		},
		NoColor:      true,
		PlanFilePath: "plan.out",
	})
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	droplet := plan.ResourcePlannedValuesMap["digitalocean_droplet.vpn_gateway"]
	assert.Equal(t, uniqueId, droplet.AttributeValues["name"])
}
