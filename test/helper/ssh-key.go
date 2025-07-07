package helper

import (
	"context"
	"github.com/charmbracelet/keygen"
	"github.com/digitalocean/godo"
	"golang.org/x/crypto/ssh"
	"log"
	"strings"
)

func CreateSshKey(client *godo.Client, keyName string) *godo.Key {
	log.Printf("Generating SSH key pair: %s", keyName)
	keyPair, err := keygen.New("")
	if err != nil {
		log.Panicf("Error generating SSH key pair: %v", err)
	}
	log.Printf("Adding SSH public key to DO: %s", keyName)
	keyCreateRequest := &godo.KeyCreateRequest{
		Name:      keyName,
		PublicKey: string(ssh.MarshalAuthorizedKey(keyPair.PublicKey())),
	}
	ctx := context.TODO()
	key, _, err := client.Keys.Create(ctx, keyCreateRequest)
	if err != nil {
		log.Panicf("Error adding SSH public key to DO: %v", err)
	}
	log.Printf("Added SSH public key to DO: %s (%v)", key.Name, key.ID)
	return key
}

func DeleteSshKey(client *godo.Client, keyId int) {
	log.Printf("Deleting SSH key pair from DO: %v", keyId)
	ctx := context.TODO()

	// First try to fetch the key to see if it exists
	_, _, err := client.Keys.GetByID(ctx, keyId)
	if err != nil {
		if strings.Contains(err.Error(), "404") {
			log.Printf("SSH key with ID %v already deleted or not found", keyId)
			return
		}
		log.Printf("Error checking SSH key existence: %v", err)
		return
	}

	// Try to delete the key
	_, err = client.Keys.DeleteByID(ctx, keyId)
	if err != nil {
		log.Printf("Error removing SSH public key from DO: %v", err)
	} else {
		log.Printf("Successfully deleted SSH key ID %v", keyId)
	}
}
