# ACR names must be globally unique and alphanumeric only, so we append a short
# random suffix to the project token.
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_container_registry" "main" {
  name                = "acr${var.name_token}${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled
  tags                = var.tags
}
