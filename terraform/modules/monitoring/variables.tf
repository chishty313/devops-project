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
  description = "Resource group to create the workspace in."
}

variable "retention_in_days" {
  type        = number
  description = "Log retention period."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the workspace."
  default     = {}
}
