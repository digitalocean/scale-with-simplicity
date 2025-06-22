output "aws_instance_ip" {
  description = "IP Address of the EC2 Instance created for testing"
  value       = aws_instance.t4g_nano.private_ip
}

output "doks_cluster_id" {
  description = "The Id of the DOKS cluster. This value is used in the testing of the module."
  value = digitalocean_kubernetes_cluster.vpn_test.id
}

output "helm_route_install_command" {
  description = "Commands used to install the vpn-route helm chart into the created DOKS cluster"
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.vpn_test.name}; helm upgrade vpn-route ../helm/vpn-route --install --set awsVpcCidr=${var.aws_vpc_cidr} --set vpnGwIp=${module.do_vpn_droplet.vpn_gateway_ipv4_address_private}"
}

output "ping_test_command" {
  description = "Commands used to deploy a pod into the DOKS cluster and ping the EC2 instance"
  value       = "kubectl run -it --rm test-pod --image=nicolaka/netshoot -- ping ${aws_instance.t4g_nano.private_ip}"
}