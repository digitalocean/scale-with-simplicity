name_prefix         = "vllm-nfs"
region              = "nyc2"
vpc_cidr            = "10.200.0.0/22"
doks_cluster_subnet = "172.16.0.0/20"
doks_service_subnet = "192.168.0.0/22"
nfs_size_gb         = 200
# 1 is the minimum needed to validte the RA
gpu_node_count      = 1
