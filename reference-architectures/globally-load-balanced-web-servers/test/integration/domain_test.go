package integration

import (
	"github.com/digitalocean/godo"
	"github.com/gruntwork-io/terratest/modules/random"
	"helpers/helpers"
	"os"
	"testing"
)

func TestCreateDestroyDomain(t *testing.T) {
	testDomainName := random.UniqueId()
	parentDomainName := "sws-test.jjk3.com"
	client := godo.NewFromToken(os.Getenv("DIGITALOCEAN_ACCESS_TOKEN"))
	helpers.CreateTestDomain(client, parentDomainName, testDomainName)
	helpers.DeleteTestDomain(client, parentDomainName, testDomainName)
}
