package helper

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// PodRunOptions configures the behavior of RunPod
type PodRunOptions struct {
	Name           string               // Pod name (if empty, generates unique name)
	Namespace      string               // Kubernetes namespace (defaults to kubectlOptions.Namespace)
	Image          string               // Container image
	Command        []string             // Command to execute
	RestartPolicy  corev1.RestartPolicy // Default: Never
	MaxWaitSeconds int                  // Max time to wait for completion (default: 60)
}

// PodRunResult contains the results from a pod execution
type PodRunResult struct {
	PodName string
	Logs    string
	Phase   corev1.PodPhase
}

// RunPod creates a pod, waits for completion, retrieves logs, and cleans up.
// It uses the Kubernetes client-go library directly instead of kubectl CLI commands.
// The pod is automatically deleted after logs are retrieved, even if an error occurs.
func RunPod(t *testing.T, kubectlOptions *k8s.KubectlOptions, opts PodRunOptions) (*PodRunResult, error) {
	// Get kubernetes clientset from terratest
	clientset, err := k8s.GetKubernetesClientFromOptionsE(t, kubectlOptions)
	if err != nil {
		return nil, fmt.Errorf("failed to get kubernetes client: %w", err)
	}

	ctx := context.Background()

	// Determine namespace
	namespace := opts.Namespace
	if namespace == "" {
		namespace = kubectlOptions.Namespace
	}
	if namespace == "" {
		namespace = "default"
	}

	// Generate pod name if not provided
	podName := opts.Name
	if podName == "" {
		podName = fmt.Sprintf("test-pod-%s", strings.ToLower(random.UniqueId()))
	}

	// Set default restart policy
	restartPolicy := opts.RestartPolicy
	if restartPolicy == "" {
		restartPolicy = corev1.RestartPolicyNever
	}

	// Set default max wait time
	maxWait := opts.MaxWaitSeconds
	if maxWait == 0 {
		maxWait = 60
	}

	// Create pod spec
	podSpec := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      podName,
			Namespace: namespace,
		},
		Spec: corev1.PodSpec{
			RestartPolicy: restartPolicy,
			Containers: []corev1.Container{
				{
					Name:    "main",
					Image:   opts.Image,
					Command: opts.Command,
				},
			},
		},
	}

	// Create pod using client-go
	logger.Logf(t, "Creating pod %s in namespace %s", podName, namespace)
	_, err = clientset.CoreV1().Pods(namespace).Create(ctx, podSpec, metav1.CreateOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to create pod: %w", err)
	}

	// Ensure cleanup - delete pod even if test fails
	defer func() {
		logger.Logf(t, "Deleting pod %s", podName)
		err := clientset.CoreV1().Pods(namespace).Delete(ctx, podName, metav1.DeleteOptions{})
		if err != nil {
			logger.Logf(t, "Warning: failed to delete pod %s: %v", podName, err)
		}
	}()

	// Wait for pod completion using polling with retry logic
	result := &PodRunResult{PodName: podName}
	maxRetries := maxWait / 10
	if maxRetries < 1 {
		maxRetries = 1
	}
	timeBetween := 10 * time.Second

	description := fmt.Sprintf("Waiting for pod %s to complete", podName)
	_, err = retry.DoWithRetryE(t, description, maxRetries, timeBetween, func() (string, error) {
		// Use terratest's GetPod for consistency with existing patterns
		pod := k8s.GetPod(t, kubectlOptions, podName)
		result.Phase = pod.Status.Phase

		if pod.Status.Phase == corev1.PodSucceeded {
			return "Pod succeeded", nil
		}
		if pod.Status.Phase == corev1.PodFailed {
			return "", fmt.Errorf("pod failed")
		}
		return "", fmt.Errorf("pod not completed yet, current phase: %s", pod.Status.Phase)
	})

	if err != nil {
		return result, fmt.Errorf("pod did not complete successfully: %w", err)
	}

	// Get pod logs using client-go streaming API
	logger.Logf(t, "Retrieving logs from pod %s", podName)
	podLogOpts := &corev1.PodLogOptions{}
	req := clientset.CoreV1().Pods(namespace).GetLogs(podName, podLogOpts)
	podLogs, err := req.Stream(ctx)
	if err != nil {
		return result, fmt.Errorf("failed to get pod logs: %w", err)
	}
	defer podLogs.Close()

	// Read logs into buffer
	buf := new(bytes.Buffer)
	_, err = io.Copy(buf, podLogs)
	if err != nil {
		return result, fmt.Errorf("failed to read pod logs: %w", err)
	}
	result.Logs = buf.String()

	return result, nil
}
