terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Using local state for now — deliberate choice to get you moving fast.
  # Once this works end-to-end, we'll migrate to a remote backend (Azure Storage,
  # like you set up manually earlier) so state isn't just sitting on your laptop.
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}
