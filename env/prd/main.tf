module "platform" {
  source = "../../root"

  # General Variables
  environment          = "prd"
  location             = "australiaeast"
  tags                 = {
    env = "prd"
    app = "alz"
  }

  # VNET Variables
  address_space = ["10.99.0.0/16"]
  address_prefixes_1 = ["10.99.0.0/24"]
  address_prefixes_2 = ["10.99.1.0/24"]
}



