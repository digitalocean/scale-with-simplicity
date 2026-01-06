output "partner_attachment_uuid" {
  description = "The UUID of the Partner Network Connect Attachment"
  value       = digitalocean_partner_attachment.megaport.id
}