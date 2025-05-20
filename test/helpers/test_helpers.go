package helpers

import (
	"context"
	"fmt"
	"github.com/digitalocean/godo"
	"log"
)

func CreateTestDomain(client *godo.Client, parentFqdn, testDomainName string) {
	testDomainFqdn := fmt.Sprintf("%s.%s", testDomainName, parentFqdn)
	domainCreateRequest := &godo.DomainCreateRequest{Name: testDomainFqdn}
	ctx := context.TODO()

	log.Printf("Creating domain: %s", testDomainFqdn)
	_, _, err := client.Domains.Create(ctx, domainCreateRequest)
	if err != nil {
		log.Panicf("Failed to create domain %s: %v", testDomainFqdn, err)
	}
	log.Printf("Successfully created domain: %s", testDomainFqdn)
	log.Printf("Creating NS records in %s", parentFqdn)
	for i := 1; i < 4; i++ {
		recordCreateRequest := &godo.DomainRecordEditRequest{
			Type: "NS",
			Name: testDomainName,
			Data: fmt.Sprintf("ns%v.digitalocean.com.", i),
			TTL:  1800,
		}
		_, _, err := client.Domains.CreateRecord(ctx, parentFqdn, recordCreateRequest)
		if err != nil {
			log.Panicf("Failed to create NS record %d for domain %s: %v", i, testDomainFqdn, err)
		}
	}
	log.Printf("Successfully created NS records in %s", parentFqdn)
}

func DeleteTestDomain(client *godo.Client, parentFqdn, testDomainName string) {
	ctx := context.TODO()
	testDomainFqdn := fmt.Sprintf("%s.%s", testDomainName, parentFqdn)
	log.Printf("Deleting domain: %s", testDomainFqdn)
	_, err := client.Domains.Delete(ctx, testDomainFqdn)
	if err != nil {
		log.Panicf("Failed to delete domain %s: %v", testDomainFqdn, err)
	}
	log.Printf("Successfully deleted domain: %s", testDomainFqdn)
	log.Printf("Deleting NS records in %s", parentFqdn)
	nsRecords, _, err := client.Domains.RecordsByName(ctx, parentFqdn, testDomainFqdn, nil)
	if err != nil {
		log.Panicf("Failed to get NS records %s in domain %s: %v", testDomainFqdn, parentFqdn, err)
	}
	for _, record := range nsRecords {
		_, err := client.Domains.DeleteRecord(ctx, parentFqdn, record.ID)
		if err != nil {
			log.Panicf("Failed to delete NS record %d for domain %s: %v", record.ID, testDomainFqdn, err)
		}
	}
}
