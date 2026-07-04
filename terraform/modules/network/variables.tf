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
  description = "Resource group to create network resources in."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

variable "vnet_cidr" {
  type        = string
  description = "Address space for the virtual network."
  default     = "10.20.0.0/16"
}

variable "aks_subnet_cidr" {
  type        = string
  description = "Address prefix for the AKS node subnet."
  default     = "10.20.1.0/24"
}

variable "db_subnet_cidr" {
  type        = string
  description = "Address prefix for the delegated PostgreSQL subnet."
  default     = "10.20.2.0/24"
}
