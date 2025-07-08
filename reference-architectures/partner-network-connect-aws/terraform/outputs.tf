output "aws_instance_ip" {
  description = "IP Address of the EC2 Instance created for testing"
  value       = aws_instance.t4g_nano.private_ip
}

output "kubeconfig_save_command" {
  description = "Commands used to install the vpn-route helm chart into the created DOKS cluster"
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.pnc_test.name}"
}

output "ping_test_command" {
  description = "Commands used to deploy a pod into the DOKS cluster and ping the EC2 instance"
  value       = "kubectl run -it --rm test-pod --image=nicolaka/netshoot -- ping ${aws_instance.t4g_nano.private_ip}"
}

output "partner_attachment_uuid_red" {
  description = "The UUID of the Partner Network Connect Attachment for the Red Diversity Zone"
  value       = module.pnc_red.partner_attachment_uuid
}

output "partner_attachment_uuid_blue" {
  description = "The UUID of the Partner Network Connect Attachment for the Blue Diversity Zone whehn HA is enabled"
  value       = var.ha_enabled ? module.pnc_blue[0].partner_attachment_uuid : null
}
