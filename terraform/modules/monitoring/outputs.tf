output "id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.main.id
}

output "name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.main.name
}
