variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "southindia"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-jobtrackr-dev"
}

variable "mysql_admin_username" {
  description = "MySQL admin username"
  type        = string
  default     = "mysqladmin"
}

variable "mysql_admin_password" {
  description = "MySQL admin password — set this in terraform.tfvars, never commit it"
  type        = string
  sensitive   = true
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name"
  type        = string
}

variable "mysql_server_name" {
  description = "Globally unique MySQL Flexible Server name"
  type        = string
}
