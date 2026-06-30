terraform {
  backend "azurerm" {
    use_azuread_auth     = true
    use_cli              = true
    use_oidc             = true

    subscription_id      = "43d3f387-48d5-44d4-973f-32d4254cc4f3" # tfstate 所在订阅
    tenant_id            = "a703322f-bd88-408f-b89c-7d4160275b60"
    resource_group_name  = "rg-hub"
    storage_account_name = "hubsto1"
    container_name       = "tfstatefilecontainer"
    key                  = "dev.vwan.terraform.tfstate"
  }
}