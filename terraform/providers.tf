terraform {
  required_version = "~> 1.10"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
      #version = "~> 3.0.2"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.5.0"
    }
  }
}

variable "proxmox_api_url" {
  type = string
  validation {
    condition     = can(regex("^https?://.*(:[0-9]+)?/api2/json/?$", var.proxmox_api_url))
    error_message = "The url must be something like 'https://url:8006/api2/json'."
  }
}
variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
  validation {
    condition     = can(regex("^.*@.*!.*$", var.proxmox_api_token_id))
    error_message = "The token_id must be something like 'user@pam!name'."
  }
}
variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-5][0-9a-fA-F]{3}-[089abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.proxmox_api_token_secret))
    error_message = "The token_secret must be a valid uuid4 token."
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  #pm_parallel         = 2

  pm_tls_insecure = true

  # Debug
  # pm_log_enable = true
  # pm_log_file   = "terraform-plugin-proxmox.log"
  # pm_debug      = true
  # pm_log_levels = {
  #   _default    = "debug"
  #   _capturelog = ""
  # }
}

variable "dns_server" {
  type        = string
  description = "Authoritative server IP"
  default     = "0.0.0.0"
  validation {
    condition     = can(regex("^([0-9]{1,3}[.]){3}[0-9]{1,3}$", var.dns_server))
    error_message = "Invalid server IP"
  }
}

variable "dns_key_name" {
  type        = string
  description = "Tsig key name"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_.]+\\.$", var.dns_key_name))
    error_message = "Key name cannot be empty and must end with a dot"
  }
}

variable "dns_key_algorithm" {
  type        = string
  description = "Tsig key algorithm"
  default     = "hmac-sha256"
  validation {
    condition     = can(regex("^hmac-sha(1|2|256|256-128|512|512-128)$", var.dns_key_algorithm))
    error_message = "Invalid tsig key algorithm"
  }
}

variable "dns_key_secret" {
  type        = string
  description = "Tsig key secret"
  sensitive   = true
  validation {
    condition     = length(var.dns_key_secret) >= 8
    error_message = "The key cannot be this short"
  }
}

provider "dns" {
  update {
    server        = var.dns_server
    key_name      = var.dns_key_name
    key_algorithm = var.dns_key_algorithm
    key_secret    = var.dns_key_secret
  }
}
