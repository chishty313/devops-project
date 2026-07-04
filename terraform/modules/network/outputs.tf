output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "ID of the AKS node subnet."
  value       = azurerm_subnet.aks.id
}

output "db_subnet_id" {
  description = "ID of the delegated PostgreSQL subnet."
  value       = azurerm_subnet.db.id
}
