module "platform" {
  source = "../../root"

  # General Variables
  environment          = "dev"
  location             = "eastasia"
  tags                 = {
    env = "dev"
    app = "vwan"
  }

  # VNET Variables
  address_space = ["10.131.0.0/22"]
  address_prefixes_1 = ["10.131.0.0/24"]
  address_prefixes_2 = ["10.131.1.0/24"]
}



