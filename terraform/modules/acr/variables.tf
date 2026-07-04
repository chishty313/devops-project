variable "name_token" {
  type        = string
  description = "Alphanumeric token for the ACR name (no hyphens allowed by Azure)."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create the registry in."
}

variable "sku" {
  type        = string
  description = "ACR SKU (Basic is fine for this project)."
  default     = "Basic"
}

variable "admin_enabled" {
  type        = bool
  description = "Whether to enable the ACR admin user (a shared credential). Kept off by default; managed-identity AcrPull is preferred."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the registry."
  default     = {}
}
