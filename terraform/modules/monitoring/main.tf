# Log Analytics workspace — the destination for AKS container logs and metrics
# (wired into the cluster via the oms_agent add-on in the AKS module).
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}
