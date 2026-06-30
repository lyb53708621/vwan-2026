provider "azurerm" {
  features {
  }
}

provider "azurerm" {
  alias = "hub-sub"
  subscription_id = var.hub-sub
  resource_provider_registrations = "none"
  features {}
}