output "server_fqdn" {
  description = "Private DNS name of the PostgreSQL host (resolvable only inside the VNet)."
  value       = "${azurerm_private_dns_a_record.db.name}.${azurerm_private_dns_zone.internal.name}"
}

output "server_private_ip" {
  description = "Private IP of the database VM."
  value       = azurerm_network_interface.db.private_ip_address
}

output "database_name" {
  description = "Application database name."
  value       = var.database_name
}

output "admin_username" {
  description = "Database user the backend connects as."
  value       = var.db_username
}

output "admin_password" {
  description = "Generated password for the database user (sensitive)."
  value       = random_password.app.result
  sensitive   = true
}
