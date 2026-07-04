output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_fqdn" {
  description = "API server FQDN (the cluster endpoint)."
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "node_resource_group" {
  description = "Auto-created resource group holding the cluster's nodes and load balancers."
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster (sensitive)."
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}
