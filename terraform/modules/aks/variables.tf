variable "name_prefix" {
  type        = string
  description = "Prefix for resource names, e.g. devops-dev."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create the cluster in."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

variable "aks_subnet_id" {
  type        = string
  description = "Subnet ID for the AKS node pool."
}

variable "vnet_id" {
  type        = string
  description = "VNet ID — scope for the cluster identity's network role."
}

variable "acr_id" {
  type        = string
  description = "ACR ID — scope for the kubelet's pull role."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace for the monitoring add-on."
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version. null lets AKS choose its default."
  default     = null
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the system node pool."
  default     = 2
}

variable "node_size" {
  type        = string
  description = "VM size for the node pool."
  default     = "Standard_B2s"
}

variable "cluster_network_role" {
  type        = string
  description = "Role for the cluster identity on the VNet. Best practice is 'Network Contributor'; override to 'Owner' where a constrained Owner role can only assign Owner."
  default     = "Network Contributor"
}

variable "kubelet_acr_role" {
  type        = string
  description = "Role for the kubelet identity on the ACR. Best practice is 'AcrPull'; override to 'Owner' under the same constraint."
  default     = "AcrPull"
}
