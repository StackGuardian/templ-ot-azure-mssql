variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix))
    error_message = "Use 2-16 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "germanywestcentral"
}

# Grouped so the StackGuardian form can show them in one "Advanced Settings" section.
variable "advanced_settings" {
  description = "Settings most deployments keep at their defaults"
  type = object({
    vnet_cidr             = optional(string, "10.0.0.0/16") # Address space of the VNet
    sku_name              = optional(string, "Basic")       # SKU of the database: Basic, Standard (S0-S2), General Purpose serverless or provisioned
    max_size_gb           = optional(number, 2)             # Maximum size of the database in GB (Basic: up to 2)
    database_name         = optional(string, "app")         # Name of the database
    administrator_login   = optional(string, "sqladmin")    # Admin user name. The password is generated and stored in Key Vault.
    password_version      = optional(number, 1)             # Increase to generate and set a new admin password
    backup_retention_days = optional(number, 7)             # Days of point-in-time restore (1-35, Basic: up to 7)
    log_retention_days    = optional(number, 90)            # Retention of the logs in Log Analytics
    tags                  = optional(map(string), {})       # Additional tags for all resources
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(cidrnetmask(var.advanced_settings.vnet_cidr))
    error_message = "vnet_cidr must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = contains(["Basic", "S0", "S1", "S2", "GP_S_Gen5_1", "GP_S_Gen5_2", "GP_Gen5_2", "GP_Gen5_4"], var.advanced_settings.sku_name)
    error_message = "SKU must be one of Basic, S0, S1, S2, GP_S_Gen5_1, GP_S_Gen5_2, GP_Gen5_2 or GP_Gen5_4."
  }

  validation {
    condition     = var.advanced_settings.max_size_gb >= 1 && var.advanced_settings.max_size_gb <= (var.advanced_settings.sku_name == "Basic" ? 2 : 250)
    error_message = "Maximum size must be 1 to 2 GB for Basic and 1 to 250 GB for the other SKUs."
  }

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_-]{0,63}$", var.advanced_settings.database_name)) && !contains(["master", "model", "msdb", "tempdb"], lower(var.advanced_settings.database_name))
    error_message = "Database name: 1-64 letters, digits, underscores or hyphens, starting with a letter. System database names are not allowed."
  }

  validation {
    condition = (
      can(regex("^[A-Za-z][A-Za-z0-9_]{0,31}$", var.advanced_settings.administrator_login)) &&
      !contains(["admin", "administrator", "sa", "root", "dbmanager", "loginmanager", "dbo", "guest", "public", "sys"], lower(var.advanced_settings.administrator_login))
    )
    error_message = "Administrator login: 1-32 letters, digits or underscores, starting with a letter. Names like admin, sa or root are reserved by Azure SQL."
  }

  validation {
    condition     = var.advanced_settings.password_version >= 1
    error_message = "password_version must be 1 or higher."
  }

  validation {
    condition     = var.advanced_settings.backup_retention_days >= 1 && var.advanced_settings.backup_retention_days <= (var.advanced_settings.sku_name == "Basic" ? 7 : 35)
    error_message = "Backup retention must be 1 to 7 days for Basic and 1 to 35 days for the other SKUs."
  }

  validation {
    condition     = var.advanced_settings.log_retention_days >= 30 && var.advanced_settings.log_retention_days <= 730
    error_message = "Log Analytics retention must be between 30 and 730 days."
  }
}
