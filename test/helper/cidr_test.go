package helper

import (
	"context"
	"net"
	"testing"

	"github.com/digitalocean/godo"
	"github.com/stretchr/testify/assert"
)

// MockVPCsService implements a minimal mock of the VPCsService interface for testing
type MockVPCsService struct {
	vpcs []*godo.VPC
	err  error
}

func (m *MockVPCsService) List(ctx context.Context, listOpt *godo.ListOptions) ([]*godo.VPC, *godo.Response, error) {
	if m.err != nil {
		return nil, nil, m.err
	}

	resp := &godo.Response{
		Links: &godo.Links{},
	}

	return m.vpcs, resp, nil
}

// Unused methods required by the interface
func (m *MockVPCsService) Get(context.Context, string) (*godo.VPC, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) Create(context.Context, *godo.VPCCreateRequest) (*godo.VPC, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) Update(context.Context, string, *godo.VPCUpdateRequest) (*godo.VPC, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) Set(context.Context, string, ...godo.VPCSetField) (*godo.VPC, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) Delete(context.Context, string) (*godo.Response, error) {
	return nil, nil
}

func (m *MockVPCsService) ListMembers(context.Context, string, *godo.VPCListMembersRequest, *godo.ListOptions) ([]*godo.VPCMember, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) CreateVPCPeering(context.Context, *godo.VPCPeeringCreateRequest) (*godo.VPCPeering, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) GetVPCPeering(context.Context, string) (*godo.VPCPeering, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) ListVPCPeerings(context.Context, *godo.ListOptions) ([]*godo.VPCPeering, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) UpdateVPCPeering(context.Context, string, *godo.VPCPeeringUpdateRequest) (*godo.VPCPeering, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) DeleteVPCPeering(context.Context, string) (*godo.Response, error) {
	return nil, nil
}

func (m *MockVPCsService) CreateVPCPeeringByVPCID(context.Context, string, *godo.VPCPeeringCreateRequestByVPCID) (*godo.VPCPeering, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) ListVPCPeeringsByVPCID(context.Context, string, *godo.ListOptions) ([]*godo.VPCPeering, *godo.Response, error) {
	return nil, nil, nil
}

func (m *MockVPCsService) UpdateVPCPeeringByVPCID(context.Context, string, string, *godo.VPCPeeringUpdateRequest) (*godo.VPCPeering, *godo.Response, error) {
	return nil, nil, nil
}

// MockKubernetesService implements a minimal mock of the KubernetesService interface for testing
type MockKubernetesService struct {
	clusters []*godo.KubernetesCluster
	err      error
}

func (m *MockKubernetesService) List(ctx context.Context, opts *godo.ListOptions) ([]*godo.KubernetesCluster, *godo.Response, error) {
	if m.err != nil {
		return nil, nil, m.err
	}
	resp := &godo.Response{
		Links: &godo.Links{},
	}
	return m.clusters, resp, nil
}

// Unused methods required by the interface
func (m *MockKubernetesService) Create(context.Context, *godo.KubernetesClusterCreateRequest) (*godo.KubernetesCluster, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) Get(context.Context, string) (*godo.KubernetesCluster, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetUser(context.Context, string) (*godo.KubernetesClusterUser, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetUpgrades(context.Context, string) ([]*godo.KubernetesVersion, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetKubeConfig(context.Context, string) (*godo.KubernetesClusterConfig, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetKubeConfigWithExpiry(context.Context, string, int64) (*godo.KubernetesClusterConfig, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetCredentials(context.Context, string, *godo.KubernetesClusterCredentialsGetRequest) (*godo.KubernetesClusterCredentials, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) Update(context.Context, string, *godo.KubernetesClusterUpdateRequest) (*godo.KubernetesCluster, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) Upgrade(context.Context, string, *godo.KubernetesClusterUpgradeRequest) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) Delete(context.Context, string) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) DeleteSelective(context.Context, string, *godo.KubernetesClusterDeleteSelectiveRequest) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) DeleteDangerous(context.Context, string) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) ListAssociatedResourcesForDeletion(context.Context, string) (*godo.KubernetesAssociatedResources, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) CreateNodePool(ctx context.Context, clusterID string, req *godo.KubernetesNodePoolCreateRequest) (*godo.KubernetesNodePool, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetNodePool(ctx context.Context, clusterID, poolID string) (*godo.KubernetesNodePool, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetNodePoolTemplate(ctx context.Context, clusterID string, nodePoolName string) (*godo.KubernetesNodePoolTemplate, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) ListNodePools(ctx context.Context, clusterID string, opts *godo.ListOptions) ([]*godo.KubernetesNodePool, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) UpdateNodePool(ctx context.Context, clusterID, poolID string, req *godo.KubernetesNodePoolUpdateRequest) (*godo.KubernetesNodePool, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) RecycleNodePoolNodes(ctx context.Context, clusterID, poolID string, req *godo.KubernetesNodePoolRecycleNodesRequest) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) DeleteNodePool(ctx context.Context, clusterID, poolID string) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) DeleteNode(ctx context.Context, clusterID, poolID, nodeID string, req *godo.KubernetesNodeDeleteRequest) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) GetOptions(context.Context) (*godo.KubernetesOptions, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) AddRegistry(ctx context.Context, req *godo.KubernetesClusterRegistryRequest) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) RemoveRegistry(ctx context.Context, req *godo.KubernetesClusterRegistryRequest) (*godo.Response, error) {
	return nil, nil
}
func (m *MockKubernetesService) RunClusterlint(ctx context.Context, clusterID string, req *godo.KubernetesRunClusterlintRequest) (string, *godo.Response, error) {
	return "", nil, nil
}
func (m *MockKubernetesService) GetClusterlintResults(ctx context.Context, clusterID string, req *godo.KubernetesGetClusterlintRequest) ([]*godo.ClusterlintDiagnostic, *godo.Response, error) {
	return nil, nil, nil
}
func (m *MockKubernetesService) GetClusterStatusMessages(ctx context.Context, clusterID string, req *godo.KubernetesGetClusterStatusMessagesRequest) ([]*godo.KubernetesClusterStatusMessage, *godo.Response, error) {
	return nil, nil, nil
}

func TestGetCidrBlock(t *testing.T) {
	tests := []struct {
		name           string
		baseNetwork    string
		prefixLength   int
		existingVPCs   []*godo.VPC
		existingK8s    []*godo.KubernetesCluster
		expectedPrefix string
		expectError    bool
	}{
		{
			name:         "No existing networks",
			baseNetwork:  "10.0.0.0",
			prefixLength: 24,
			existingVPCs: []*godo.VPC{},
			existingK8s:  []*godo.KubernetesCluster{},
			expectedPrefix: "10.0.0.0/24",
			expectError:    false,
		},
		{
			name:         "One existing network",
			baseNetwork:  "10.0.0.0",
			prefixLength: 24,
			existingVPCs: []*godo.VPC{
				{IPRange: "10.0.0.0/24"},
			},
			existingK8s: []*godo.KubernetesCluster{},
			expectedPrefix: "10.0.1.0/24",
			expectError:    false,
		},
		{
			name:         "Support multiple existing 10.0.0.0 networks with different prefix lengths",
			baseNetwork:  "10.0.0.0",
			prefixLength: 16,
			existingVPCs: []*godo.VPC{
				{IPRange: "10.0.0.0/24"},
				{IPRange: "10.1.1.0/24"},
				{IPRange: "10.2.0.0/16"},
			},
			existingK8s: []*godo.KubernetesCluster{},
			expectedPrefix: "10.3.0.0/16",
			expectError:    false,
		},
		{
			name:         "Support multiple existing 172.16.0.0 networks with different prefix lengths",
			baseNetwork:  "172.16.0.0",
			prefixLength: 16,
			existingVPCs: []*godo.VPC{
				{IPRange: "172.16.0.0/16"},
				{IPRange: "172.17.1.0/24"},
				{IPRange: "172.18.0.0/17"},
			},
			existingK8s: []*godo.KubernetesCluster{},
			expectedPrefix: "172.19.0.0/16",
			expectError:    false,
		},
		{
			name:         "Support multiple existing 192.168.0.0 networks with different prefix lengths",
			baseNetwork:  "192.168.0.0",
			prefixLength: 16,
			existingVPCs: []*godo.VPC{
				{IPRange: "192.168.0.0/16"},
				{IPRange: "192.169.1.0/24"},
				{IPRange: "192.170.0.0/17"},
			},
			existingK8s: []*godo.KubernetesCluster{},
			expectedPrefix: "192.171.0.0/16",
			expectError:    false,
		},
		{
			name:         "Multiple existing networks",
			baseNetwork:  "10.0.0.0",
			prefixLength: 24,
			existingVPCs: []*godo.VPC{
				{IPRange: "10.0.0.0/24"},
				{IPRange: "10.0.1.0/24"},
				{IPRange: "10.0.2.0/24"},
			},
			existingK8s: []*godo.KubernetesCluster{},
			expectedPrefix: "10.0.3.0/24",
			expectError:    false,
		},
		{
			name:         "Existing VPC and K8s clusters",
			baseNetwork:  "10.0.0.0",
			prefixLength: 24,
			existingVPCs: []*godo.VPC{
				{IPRange: "10.0.0.0/24"},
			},
			existingK8s: []*godo.KubernetesCluster{
				{ClusterSubnet: "10.0.1.0/24", ServiceSubnet: "10.0.2.0/24"},
			},
			expectedPrefix: "10.0.3.0/24",
			expectError:    false,
		},
		{
			name:         "Not a network base network",
			baseNetwork:  "invalid-ip",
			prefixLength: 24,
			existingVPCs: []*godo.VPC{},
			existingK8s:  []*godo.KubernetesCluster{},
			expectError:  true,
		},
		{
			name:         "Invalid base network",
			baseNetwork:  "10.300.0.0",
			prefixLength: 24,
			existingVPCs: []*godo.VPC{},
			existingK8s:  []*godo.KubernetesCluster{},
			expectError:  true,
		},
		{
			name:         "Invalid prefix length",
			baseNetwork:  "10.0.0.0",
			prefixLength: 33,
			existingVPCs: []*godo.VPC{},
			existingK8s:  []*godo.KubernetesCluster{},
			expectError:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a mock client
			client := &godo.Client{}
			
			// Set up mock VPC service
			client.VPCs = &MockVPCsService{
				vpcs: tt.existingVPCs,
			}
			
			// Set up mock Kubernetes service
			client.Kubernetes = &MockKubernetesService{
				clusters: tt.existingK8s,
			}

			// Call the function
			cidr, err := getCidrBlock(context.Background(), client, tt.baseNetwork, tt.prefixLength)

			// Check results
			if tt.expectError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expectedPrefix, cidr)

				// Validate that the returned CIDR is valid
				_, _, err := net.ParseCIDR(cidr)
				assert.NoError(t, err, "Returned CIDR should be valid")
			}
		})
	}
}

// TestOverlapsWithAny tests the overlapsWithAny function
func TestOverlapsWithAny(t *testing.T) {
	tests := []struct {
		name      string
		candidate string
		existing  []string
		expected  bool
	}{
		{
			name:      "No overlap",
			candidate: "10.0.0.0/24",
			existing:  []string{"10.0.1.0/24", "10.0.2.0/24"},
			expected:  false,
		},
		{
			name:      "Direct overlap",
			candidate: "10.0.1.0/24",
			existing:  []string{"10.0.1.0/24", "10.0.2.0/24"},
			expected:  true,
		},
		{
			name:      "Subnet overlap",
			candidate: "10.0.0.0/16",
			existing:  []string{"10.0.1.0/24", "10.0.2.0/24"},
			expected:  true,
		},
		{
			name:      "Supernet overlap",
			candidate: "10.0.1.0/28",
			existing:  []string{"10.0.1.0/24", "10.0.2.0/24"},
			expected:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Parse the candidate CIDR
			_, candidateNet, err := net.ParseCIDR(tt.candidate)
			assert.NoError(t, err)

			// Parse the existing CIDRs
			existingNets := make([]*net.IPNet, 0, len(tt.existing))
			for _, cidr := range tt.existing {
				_, network, err := net.ParseCIDR(cidr)
				assert.NoError(t, err)
				existingNets = append(existingNets, network)
			}

			// Check for overlap
			result := overlapsWithAny(candidateNet, existingNets)
			assert.Equal(t, tt.expected, result)
		})
	}
}

// TestNetworksOverlap tests the networksOverlap function
func TestNetworksOverlap(t *testing.T) {
	tests := []struct {
		name     string
		network1 string
		network2 string
		expected bool
	}{
		{
			name:     "No overlap",
			network1: "10.0.0.0/24",
			network2: "10.0.1.0/24",
			expected: false,
		},
		{
			name:     "Identical networks",
			network1: "10.0.1.0/24",
			network2: "10.0.1.0/24",
			expected: true,
		},
		{
			name:     "Subnet overlap",
			network1: "10.0.0.0/16",
			network2: "10.0.1.0/24",
			expected: true,
		},
		{
			name:     "Supernet overlap",
			network1: "10.0.1.0/28",
			network2: "10.0.1.0/24",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Parse the networks
			_, net1, err := net.ParseCIDR(tt.network1)
			assert.NoError(t, err)
			_, net2, err := net.ParseCIDR(tt.network2)
			assert.NoError(t, err)

			// Check for overlap
			result := networksOverlap(net1, net2)
			assert.Equal(t, tt.expected, result)
		})
	}
}
