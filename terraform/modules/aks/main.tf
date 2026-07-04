# User-assigned identity for the cluster control plane. Created up front so we can
# grant it network permissions BEFORE the cluster is created (a system-assigned
# identity wouldn't exist yet — chicken-and-egg with a custom subnet).
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# The cluster identity needs permission to manage the custom subnet (load
# balancers, etc.). Least-privilege role is "Network Contributor"; overridden to
# "Owner" here because the subscription's constrained Owner can only assign Owner.
resource "azurerm_role_assignment" "aks_network" {
  scope                = var.vnet_id
  role_definition_name = var.cluster_network_role
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name_prefix}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  tags                = var.tags

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_size
    vnet_subnet_id = var.aks_subnet_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "10.0.0.0/16"
    dns_service_ip    = "10.0.0.10"
    load_balancer_sku = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Ensure the network role exists before the cluster tries to use the subnet.
  depends_on = [azurerm_role_assignment.aks_network]
}

# Let the kubelet identity pull images from ACR. Least-privilege role is
# "AcrPull"; overridden to "Owner" under the same constraint as above.
resource "azurerm_role_assignment" "kubelet_acr" {
  scope                = var.acr_id
  role_definition_name = var.kubelet_acr_role
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
