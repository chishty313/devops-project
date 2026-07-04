variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "eastus"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)."
  default     = "dev"
}

variable "project" {
  type        = string
  description = "Short project name, used as a prefix in resource names."
  default     = "devops"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for AKS. null lets AKS choose its default."
  default     = null
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the AKS system node pool."
  default     = 2
}

variable "node_size" {
  type        = string
  description = "VM size for AKS nodes."
  default     = "Standard_B2s"
}

variable "cluster_network_role" {
  type        = string
  description = "Role for the AKS cluster identity on the VNet."
  default     = "Network Contributor"
}

variable "kubelet_acr_role" {
  type        = string
  description = "Role for the AKS kubelet identity on the ACR."
  default     = "AcrPull"
}
