output "id" {
  description = "Resource ID of the container registry."
  value       = azurerm_container_registry.main.id
}

output "login_server" {
  description = "Login server hostname, e.g. acrdevopsdev123abc.azurecr.io."
  value       = azurerm_container_registry.main.login_server
}

output "name" {
  description = "Name of the container registry."
  value       = azurerm_container_registry.main.name
}
