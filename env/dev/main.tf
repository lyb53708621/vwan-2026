# Add comments
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
  ea_vnet1_address_space = ["10.121.0.0/22"]
  ea_vnet1_address_prefixes_1 = ["10.121.0.0/24"]
  ea_vnet1_address_prefixes_2 = ["10.121.1.0/24"]
  ea_vnet2_address_space = ["10.122.0.0/22"]
  ea_vnet2_address_prefixes_1 = ["10.122.0.0/24"]
  ea_vnet2_address_prefixes_2 = ["10.122.1.0/24"]
  ae_vnet1_address_space = ["10.131.0.0/22"]
  ae_vnet1_address_prefixes_1 = ["10.131.0.0/24"]
  ae_vnet1_address_prefixes_2 = ["10.131.1.0/24"]
}



