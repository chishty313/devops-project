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
  description = "Resource group to create the database in."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

variable "db_subnet_id" {
  type        = string
  description = "Subnet ID for the database VM (no public IP)."
}

variable "vnet_id" {
  type        = string
  description = "VNet ID to link the private DNS zone to."
}

variable "aks_subnet_cidr" {
  type        = string
  description = "AKS subnet CIDR allowed to connect to Postgres."
  default     = "10.20.1.0/24"
}

variable "db_subnet_cidr" {
  type        = string
  description = "DB subnet CIDR (for local pg_hba trust)."
  default     = "10.20.2.0/24"
}

variable "vm_size" {
  type        = string
  description = "VM size for the database host."
  default     = "standard_d2as_v7"
}

variable "vm_admin_username" {
  type        = string
  description = "Linux admin user for the DB VM."
  default     = "azureuser"
}

variable "db_username" {
  type        = string
  description = "Application database user the backend connects as."
  default     = "appuser"
}

variable "database_name" {
  type        = string
  description = "Application database to create."
  default     = "appdb"
}

variable "dns_zone_name" {
  type        = string
  description = "Private DNS zone for internal records."
  default     = "devops.internal"
}
