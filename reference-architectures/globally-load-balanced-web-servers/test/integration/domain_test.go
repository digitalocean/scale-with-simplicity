package integration

import (
	"github.com/digitalocean/godo"
	"github.com/digitalocean/scale-with-simplicity/test/helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"os"
	"testing"
)

func TestCreateDestroyDomain(t *testing.T) {
	testDomainName := random.UniqueId()
	parentDomainName := "sws-test.jjk3.com"
	client := godo.NewFromToken(os.Getenv("DIGITALOCEAN_ACCESS_TOKEN"))
	helper.CreateTestDomain(client, parentDomainName, testDomainName)
	helper.DeleteTestDomain(client, parentDomainName, testDomainName)
}
