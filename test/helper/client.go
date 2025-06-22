package helper

import (
	"context"
	"fmt"
	"github.com/digitalocean/godo"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
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

// CreateK8sClient takes a godo client and a DOKS cluster ID, fetches its kubeconfig, and returns a typed Kubernetes clientset.
func CreateK8sClient(ctx context.Context, doClient *godo.Client, clusterID string) (*kubernetes.Clientset, error) {
	cfgObj, _, err := doClient.Kubernetes.GetKubeConfig(ctx, clusterID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch kubeconfig for cluster %q: %w", clusterID, err)
	}

	restCfg, err := clientcmd.RESTConfigFromKubeConfig(cfgObj.KubeconfigYAML)
	if err != nil {
		return nil, fmt.Errorf("failed to parse kubeconfig bytes: %w", err)
	}

	clientset, err := kubernetes.NewForConfig(restCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create k8s client: %w", err)
	}

	return clientset, nil
}
