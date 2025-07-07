package helper

import (
	"context"
	"errors"
	"fmt"
	"net"

	"github.com/digitalocean/godo"
)

// getCidrBlock returns a non-overlapping CIDR block for deploying Terraform-based reference architectures.
// It dynamically assigns a new CIDR block based on existing VPCs and Kubernetes clusters in the DigitalOcean account.
//
// Parameters:
//   - ctx: Context for API calls
//   - client: Authenticated DigitalOcean API client
//   - baseNetwork: Base network in CIDR notation without prefix (e.g., "10.0.0.0", "172.16.0.0")
//   - prefixLength: Desired subnet mask length (e.g., 24, 26)
//
// Returns:
//   - A string containing the next available CIDR block (e.g., "10.0.1.0/24")
//   - An error if no available block is found or if API calls fail
func getCidrBlock(ctx context.Context, client *godo.Client, baseNetwork string, prefixLength int) (string, error) {
	// Validate inputs
	if client == nil {
		return "", errors.New("godo client cannot be nil")
	}

	if prefixLength < 8 || prefixLength > 30 {
		return "", fmt.Errorf("prefix length must be between 8 and 30, got %d", prefixLength)
	}

	// Parse the base network
	baseIP := net.ParseIP(baseNetwork)
	if baseIP == nil {
		return "", fmt.Errorf("invalid base network: %s", baseNetwork)
	}

	// Ensure baseIP is an IPv4 address
	baseIP = baseIP.To4()
	if baseIP == nil {
		return "", fmt.Errorf("base network must be an IPv4 address: %s", baseNetwork)
	}

	// Get all existing CIDR blocks from VPCs and Kubernetes clusters
	existingCIDRs, err := getAllExistingCIDRs(ctx, client)
	if err != nil {
		return "", fmt.Errorf("failed to get existing CIDR blocks: %w", err)
	}

	// Parse all existing CIDRs into network objects
	existingNetworks := make([]*net.IPNet, 0, len(existingCIDRs))
	for _, cidr := range existingCIDRs {
		_, network, err := net.ParseCIDR(cidr)
		if err != nil {
			continue // Skip invalid CIDRs
		}
		existingNetworks = append(existingNetworks, network)
	}

	// Generate candidate subnets and check for overlaps
	// Start with the first subnet in the base network
	baseIPInt := ipToUint32(baseIP)
	
	// Calculate the subnet size
	subnetSize := uint32(1) << (32 - prefixLength)
	
	// Try up to 256 different subnets
	for i := uint32(0); i < 256; i++ {
		// Calculate the start IP for this subnet
		startIP := baseIPInt + (i * subnetSize)
		
		// Convert back to an IP and create the CIDR
		candidateIP := uint32ToIP(startIP)
		candidateCIDR := fmt.Sprintf("%s/%d", candidateIP.String(), prefixLength)
		
		// Parse the candidate CIDR
		_, candidateNetwork, err := net.ParseCIDR(candidateCIDR)
		if err != nil {
			continue // Skip if we can't parse it
		}
		
		// Check if this candidate overlaps with any existing network
		if !overlapsWithAny(candidateNetwork, existingNetworks) {
			return candidateCIDR, nil
		}
	}

	return "", errors.New("no available CIDR block found within the given base network")
}

// getAllExistingCIDRs retrieves all CIDR blocks from VPCs and Kubernetes clusters
func getAllExistingCIDRs(ctx context.Context, client *godo.Client) ([]string, error) {
	var cidrs []string

	// Get VPC CIDRs
	vpcCIDRs, err := getVpcCIDRs(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("failed to get VPC CIDRs: %w", err)
	}
	cidrs = append(cidrs, vpcCIDRs...)

	// Get Kubernetes cluster CIDRs
	k8sCIDRs, err := getKubernetesCIDRs(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("failed to get Kubernetes CIDRs: %w", err)
	}
	cidrs = append(cidrs, k8sCIDRs...)

	return cidrs, nil
}

// getVpcCIDRs retrieves all CIDR blocks from VPCs
func getVpcCIDRs(ctx context.Context, client *godo.Client) ([]string, error) {
	var cidrs []string
	opt := &godo.ListOptions{
		Page:    1,
		PerPage: 100,
	}

	for {
		vpcs, resp, err := client.VPCs.List(ctx, opt)
		if err != nil {
			return nil, err
		}

		for _, vpc := range vpcs {
			cidrs = append(cidrs, vpc.IPRange)
		}

		// Check if we need to paginate
		if resp.Links == nil || resp.Links.IsLastPage() {
			break
		}

		// Get the next page
		page, err := resp.Links.CurrentPage()
		if err != nil {
			return nil, err
		}
		opt.Page = page + 1
	}

	return cidrs, nil
}

// getKubernetesCIDRs retrieves all CIDR blocks from Kubernetes clusters
func getKubernetesCIDRs(ctx context.Context, client *godo.Client) ([]string, error) {
	var cidrs []string
	opt := &godo.ListOptions{
		Page:    1,
		PerPage: 100,
	}

	for {
		clusters, resp, err := client.Kubernetes.List(ctx, opt)
		if err != nil {
			return nil, err
		}

		for _, cluster := range clusters {
			// Add cluster subnet CIDR
			if cluster.ClusterSubnet != "" {
				cidrs = append(cidrs, cluster.ClusterSubnet)
			}
			
			// Add service subnet CIDR
			if cluster.ServiceSubnet != "" {
				cidrs = append(cidrs, cluster.ServiceSubnet)
			}
		}

		// Check if we need to paginate
		if resp.Links == nil || resp.Links.IsLastPage() {
			break
		}

		// Get the next page
		page, err := resp.Links.CurrentPage()
		if err != nil {
			return nil, err
		}
		opt.Page = page + 1
	}

	return cidrs, nil
}

// overlapsWithAny checks if the given network overlaps with any of the existing networks
func overlapsWithAny(candidate *net.IPNet, existingNetworks []*net.IPNet) bool {
	for _, existing := range existingNetworks {
		if networksOverlap(candidate, existing) {
			return true
		}
	}
	return false
}

// networksOverlap checks if two networks overlap
func networksOverlap(n1, n2 *net.IPNet) bool {
	// Check if either network contains the other's IP
	return n1.Contains(n2.IP) || n2.Contains(n1.IP)
}

// ipToUint32 converts an IP address to a uint32
func ipToUint32(ip net.IP) uint32 {
	ip = ip.To4()
	return uint32(ip[0])<<24 | uint32(ip[1])<<16 | uint32(ip[2])<<8 | uint32(ip[3])
}

// uint32ToIP converts a uint32 to an IP address
func uint32ToIP(n uint32) net.IP {
	ip := make(net.IP, 4)
	ip[0] = byte(n >> 24)
	ip[1] = byte(n >> 16)
	ip[2] = byte(n >> 8)
	ip[3] = byte(n)
	return ip
}
