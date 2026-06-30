terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.59.0"
    }

    #    aws = {
    #      source = "hashicorp/aws"
    #      version = "= 3.0"
    #    }
    #
    #    kubernetes = {
    #      source = "hashicorp/kubernetes"
    #      version = ">= 2.0.0"
    #    }
  }
}
