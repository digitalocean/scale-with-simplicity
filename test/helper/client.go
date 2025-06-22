package helper

import (
	"github.com/digitalocean/godo"
	"log"
	"os"
)

// CreateGodoClient reads $DIGITALOCEAN_ACCESS_TOKEN and returns a godo.Client or panics.
func CreateGodoClient() *godo.Client {
	accessToken, ok := os.LookupEnv("DIGITALOCEAN_ACCESS_TOKEN")
	if ok {
		return godo.NewFromToken(accessToken)
	}
	log.Panicln("Unable to create godo client as DIGITALOCEAN_ACCESS_TOKEN Env Var is not set. ")
	return nil
}
