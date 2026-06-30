terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.74.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "YOUR_INFRA_RG"
    storage_account_name = "YOUR_STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subid
}
