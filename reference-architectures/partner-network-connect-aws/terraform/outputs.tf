output "aws_instance_ip" {
  description = "IP Address of the EC2 Instance created for testing"
  value       = aws_instance.t4g_nano.private_ip
}

output "check_direct_connect_bgp_command" {
  value = "aws directconnect describe-virtual-interfaces --region ${var.aws_region} --virtual-interface-id ${local.aws_connection_red.vif_id} --query 'virtualInterfaces[*].{ID:virtualInterfaceId, BGPStatus:bgpPeers[0].bgpStatus}' --output table"
}

output "kubeconfig_save_command" {
  description = "Commands used to install the vpn-route helm chart into the created DOKS cluster"
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.pnc_test.name}"
}

output "ping_test_command" {
  description = "Commands used to deploy a pod into the DOKS cluster and ping the EC2 instance"
  value       = "kubectl run -it --rm test-pod --image=nicolaka/netshoot -- ping ${aws_instance.t4g_nano.private_ip}"
}