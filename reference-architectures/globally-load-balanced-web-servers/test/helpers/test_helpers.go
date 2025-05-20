package helpers

import (
	"context"
	"fmt"
	"github.com/digitalocean/godo"
)

func CreateTestDomain(client *godo.Client, parentFqdn, testDomainName string) {
	testDomainFqdn := fmt.Sprintf("%s.%s", testDomainName, parentFqdn)
	domainCreateRequest := &godo.DomainCreateRequest{Name: testDomainFqdn}
	ctx := context.TODO()
	_, _, err := client.Domains.Create(ctx, domainCreateRequest)
	if err != nil {
		fmt.Printf("Something bad happened: %s\n\n", err)
	}
	for i := 1; i < 4; i++ {
		recordCreateRequest := &godo.DomainRecordEditRequest{
			Type: "NS",
			Name: testDomainName,
			Data: fmt.Sprintf("ns%v.digitalocean.com.", i),
			TTL:  1800,
		}
		_, _, err := client.Domains.CreateRecord(ctx, parentFqdn, recordCreateRequest)
		if err != nil {
			fmt.Printf("Something bad happened: %s\n\n", err)
		}
	}
}

func DeleteTestDomain(client *godo.Client, parentFqdn, testDomainName string) {
	ctx := context.TODO()
	testDomainFqdn := fmt.Sprintf("%s.%s", testDomainName, parentFqdn)
	_, err := client.Domains.Delete(ctx, testDomainFqdn)
	if err != nil {
		fmt.Printf("Something bad happened: %s\n\n", err)
	}
	nsRecords, _, err := client.Domains.RecordsByName(ctx, parentFqdn, testDomainFqdn, nil)
	if err != nil {
		fmt.Printf("Something bad happened: %s\n\n", err)
	}
	for _, record := range nsRecords {
		_, err := client.Domains.DeleteRecord(ctx, parentFqdn, record.ID)
		if err != nil {
			fmt.Printf("Something bad happened: %s\n\n", err)
		}
	}
}
