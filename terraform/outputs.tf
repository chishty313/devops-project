output "resource_group_name" {
  description = "Name of the main resource group."
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region everything is deployed in."
  value       = azurerm_resource_group.main.location
}

output "vnet_id" {
  description = "ID of the virtual network."
  value       = module.network.vnet_id
}

output "aks_subnet_id" {
  description = "ID of the AKS node subnet."
  value       = module.network.aks_subnet_id
}

output "db_subnet_id" {
  description = "ID of the delegated PostgreSQL subnet."
  value       = module.network.db_subnet_id
}

output "acr_login_server" {
  description = "ACR login server hostname."
  value       = module.acr.login_server
}

output "acr_name" {
  description = "ACR name."
  value       = module.acr.name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = module.monitoring.id
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "cluster_endpoint" {
  description = "AKS API server FQDN."
  value       = module.aks.cluster_fqdn
}

output "node_resource_group" {
  description = "AKS node resource group."
  value       = module.aks.node_resource_group
}

output "db_server_fqdn" {
  description = "Private DNS name of the PostgreSQL host."
  value       = module.database.server_fqdn
}

output "db_server_private_ip" {
  description = "Private IP of the database VM."
  value       = module.database.server_private_ip
}

output "db_name" {
  description = "Application database name."
  value       = module.database.database_name
}

output "db_admin_username" {
  description = "PostgreSQL administrator login."
  value       = module.database.admin_username
}

output "db_admin_password" {
  description = "PostgreSQL administrator password (generated)."
  value       = module.database.admin_password
  sensitive   = true
}
