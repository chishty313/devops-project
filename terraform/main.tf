locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    project     = var.project
    environment = var.environment
    managedBy   = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source              = "./modules/network"
  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

module "monitoring" {
  source              = "./modules/monitoring"
  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

module "acr" {
  source              = "./modules/acr"
  name_token          = "${var.project}${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

module "aks" {
  source                     = "./modules/aks"
  name_prefix                = local.name_prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tags                       = local.common_tags
  aks_subnet_id              = module.network.aks_subnet_id
  vnet_id                    = module.network.vnet_id
  acr_id                     = module.acr.id
  log_analytics_workspace_id = module.monitoring.id
  kubernetes_version         = var.kubernetes_version
  node_count                 = var.node_count
  node_size                  = var.node_size
  cluster_network_role       = var.cluster_network_role
  kubelet_acr_role           = var.kubelet_acr_role
}

module "database" {
  source              = "./modules/database"
  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
  db_subnet_id        = module.network.db_subnet_id
  vnet_id             = module.network.vnet_id
}
