# Create Resource Group
resource "azurerm_resource_group" "rg-vwan" {
  name     = "rg-vwan-${var.environment}"
  location = var.location
  tags = var.tags
}

# Create VWAN Resources
## Create VWAN
resource "azurerm_virtual_wan" "vwan" {
  name                = "vwan-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  type                = "Standard"
  allow_branch_to_branch_traffic = true
  tags                = var.tags
}

## Create VWAN Hubs
resource "azurerm_virtual_hub" "vhub-eastasia" {
  name                = "vhub-eastasia-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = "10.120.0.0/22"
  branch_to_branch_traffic_enabled = "true"
  tags                = var.tags
}

resource "azurerm_virtual_hub" "vhub-australiaeast" {
  name                = "vhub-australiaeast-${var.environment}"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = "10.130.0.0/22"
  branch_to_branch_traffic_enabled = "true"
  tags                = var.tags
}

## Create VWAN Hub VPN Gateway
resource "azurerm_vpn_gateway" "vwan-vpngw-eastasia" {
  name                = "vwan-vpngw-eastasia-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_hub_id      = azurerm_virtual_hub.vhub-eastasia.id
  scale_unit          = 1
  tags                = var.tags
}

## Create VWAN Firewall 
resource "azurerm_firewall_policy" "eastasia-fwpolicy" {
  name                = "fwpolicy-eastasia-${var.environment}"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  location            = azurerm_resource_group.rg-vwan.location
  sku                 = "Standard"   # Standard / Premium / Basic

  # 可选：开启 DNS Proxy / Threat Intel
  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall_policy" "australiaeast-fwpolicy" {
  name                = "fwpolicy-australiaeast-${var.environment}"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  location            = "australiaeast"
  sku                 = "Standard"   # Standard / Premium / Basic

  # 可选：开启 DNS Proxy / Threat Intel
  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "eastasia-fwrcg" {
  name               = "DefaultRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.eastasia-fwpolicy.id
  priority           = 500

  # 网络规则
  network_rule_collection {
    name     = "Allow-Internal"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "Allow-Spoke-to-Spoke"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports     = ["*"]
    }
  }

  # 应用规则
  application_rule_collection {
    name     = "Allow-Web"
    priority = 300
    action   = "Allow"

    rule {
      name = "Allow-Microsoft"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.0.0.0/8"]
      destination_fqdns = ["*.microsoft.com", "*.office.com", "*.bing.com"]
    }
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "australiaeast-fwrcg" {
  name               = "DefaultRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.australiaeast-fwpolicy.id
  priority           = 500

  # 网络规则
  network_rule_collection {
    name     = "Allow-Internal"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "Allow-Spoke-to-Spoke"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports     = ["*"]
    }
  }

  # 应用规则
  application_rule_collection {
    name     = "Allow-Web"
    priority = 300
    action   = "Allow"

    rule {
      name = "Allow-Microsoft"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.0.0.0/8"]
      destination_fqdns = ["*.microsoft.com", "*.office.com", "*.bing.com"]
    }
  }
}

resource "azurerm_firewall" "vwan-firewall-eastasia" {
  name                = "vwan-firewall-eastasia-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  sku_name            = "AZFW_Hub"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.eastasia-fwpolicy.id

  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.vhub-eastasia.id
    public_ip_count = 1
  }

  tags                = var.tags
}

resource "azurerm_firewall" "vwan-firewall-australiaeast" {
  name                = "vwan-firewall-australiaeast-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  sku_name            = "AZFW_Hub"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.australiaeast-fwpolicy.id

  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.vhub-australiaeast.id
    public_ip_count = 1
  }

  tags                = var.tags
}

resource "azurerm_virtual_hub_routing_intent" "eastasia-routing-intent" {
  name           = "eastasia-fw-routing-intent"
  virtual_hub_id = azurerm_virtual_hub.vhub-eastasia.id

  # 私网流量（VNet↔VNet、Branch、Inter-hub）走 FW
  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_firewall.vwan-firewall-eastasia.id
  }

  # 互联网出站流量走 FW
  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_firewall.vwan-firewall-eastasia.id
  }
}

resource "azurerm_virtual_hub_routing_intent" "australiaeast-routing-intent" {
  name           = "australiaeast-fw-routing-intent"
  virtual_hub_id = azurerm_virtual_hub.vhub-australiaeast.id

  # 私网流量（VNet↔VNet、Branch、Inter-hub）走 FW
  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_firewall.vwan-firewall-australiaeast.id
  }

  # 互联网出站流量走 FW
  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_firewall.vwan-firewall-australiaeast.id
  }
}

# Create Network Resources
## Create NSG
resource "azurerm_network_security_group" "nsg-vwan-vnet1-eastasia-1" {
  name                = "nsg-vwan-vnet1-${var.environment}-eastasia-1"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
}

resource "azurerm_network_security_group" "nsg-vwan-vnet1-eastasia-2" {
  name                = "nsg-vwan-vnet1-${var.environment}-eastasia-2"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
}

resource "azurerm_network_security_group" "nsg-vwan-vnet2-eastasia-1" {
  name                = "nsg-vwan-vnet2-${var.environment}-eastasia-1"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
}

resource "azurerm_network_security_group" "nsg-vwan-vnet2-eastasia-2" {
  name                = "nsg-vwan-vnet2-${var.environment}-eastasia-2"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
}

resource "azurerm_network_security_group" "nsg-vwan-vnet1-australiaeast-1" {
  name                = "nsg-vwan-vnet1-${var.environment}-australiaeast-1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg-vwan.name
}

resource "azurerm_network_security_group" "nsg-vwan-vnet1-australiaeast-2" {
  name                = "nsg-vwan-vnet1-${var.environment}-australiaeast-2"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg-vwan.name
}

## Create VNET
resource "azurerm_virtual_network" "vnet-vwan-eastasia-1" {
  name                = "vnet-vwan-${var.environment}-eastasia-1"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  address_space       = var.ea_vnet1_address_space

  tags = var.tags
}

resource "azurerm_virtual_network" "vnet-vwan-eastasia-2" {
  name                = "vnet-vwan-${var.environment}-eastasia-2"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  address_space       = var.ea_vnet2_address_space

  tags = var.tags
}

resource "azurerm_virtual_network" "vnet-vwan-australiaeast-1" {
  name                = "vnet-vwan-${var.environment}-australiaeast-1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  address_space       = var.ae_vnet1_address_space

  tags = var.tags
}

## Create Subnet
resource "azurerm_subnet" "subnet-vwan-vnet1-eastasia-1" {
  name                 = "app-subnet-1"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-eastasia-1.name
  address_prefixes     = var.ea_vnet1_address_prefixes_1
}

resource "azurerm_subnet" "subnet-vwan-vnet1-eastasia-2" {
  name                 = "db-subnet-1"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-eastasia-1.name
  address_prefixes     = var.ea_vnet1_address_prefixes_2
}

resource "azurerm_subnet" "subnet-vwan-vnet2-eastasia-1" {
  name                 = "app-subnet-2"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-eastasia-2.name
  address_prefixes     = var.ea_vnet2_address_prefixes_1
}

resource "azurerm_subnet" "subnet-vwan-vnet2-eastasia-2" {
  name                 = "db-subnet-2"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-eastasia-2.name
  address_prefixes     = var.ea_vnet2_address_prefixes_2
}

resource "azurerm_subnet" "subnet-vwan-vnet1-australiaeast-1" {
  name                 = "app-subnet-1"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-australiaeast-1.name
  address_prefixes     = var.ae_vnet1_address_prefixes_1
}

resource "azurerm_subnet" "subnet-vwan-vnet1-australiaeast-2" {
  name                 = "db-subnet-1"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-australiaeast-1.name
  address_prefixes     = var.ae_vnet1_address_prefixes_2
}
## Associate NSG to Subnet
resource "azurerm_subnet_network_security_group_association" "ea-vnet1-subnet-1-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-vnet1-eastasia-1.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-vnet1-eastasia-1.id

  depends_on = [
    azurerm_subnet.subnet-vwan-vnet1-eastasia-1,
    azurerm_network_security_group.nsg-vwan-vnet1-eastasia-1
  ]

}

resource "azurerm_subnet_network_security_group_association" "ea-vnet1-subnet-2-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-vnet1-eastasia-2.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-vnet1-eastasia-2.id

  depends_on = [
    azurerm_subnet.subnet-vwan-vnet1-eastasia-2,
    azurerm_network_security_group.nsg-vwan-vnet1-eastasia-2
  ]
}

resource "azurerm_subnet_network_security_group_association" "ea-vnet2-subnet-1-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-vnet2-eastasia-1.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-vnet2-eastasia-1.id

  depends_on = [
    azurerm_subnet.subnet-vwan-vnet2-eastasia-1,
    azurerm_network_security_group.nsg-vwan-vnet2-eastasia-1
  ]

}

resource "azurerm_subnet_network_security_group_association" "ea-vnet2-subnet-2-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-vnet2-eastasia-2.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-vnet2-eastasia-2.id

  depends_on = [
    azurerm_subnet.subnet-vwan-vnet2-eastasia-2,
    azurerm_network_security_group.nsg-vwan-vnet2-eastasia-2
  ]
}

resource "azurerm_subnet_network_security_group_association" "ae-vnet1-subnet-1-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-vnet1-australiaeast-1.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-vnet1-australiaeast-1.id

  depends_on = [
    azurerm_subnet.subnet-vwan-vnet1-australiaeast-1,
    azurerm_network_security_group.nsg-vwan-vnet1-australiaeast-1
  ]

}

resource "azurerm_subnet_network_security_group_association" "ae-vnet1-subnet-2-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-vnet1-australiaeast-2.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-vnet1-australiaeast-2.id

  depends_on = [
    azurerm_subnet.subnet-vwan-vnet1-australiaeast-2,
    azurerm_network_security_group.nsg-vwan-vnet1-australiaeast-2
  ]
}

## VNET Connection to VWAN Hub
resource "azurerm_virtual_hub_connection" "vnet-eastasia-1-connection" {
  name                = "vnet-eastasia-1-connection"
  virtual_hub_id      = azurerm_virtual_hub.vhub-eastasia.id
  remote_virtual_network_id = azurerm_virtual_network.vnet-vwan-eastasia-1.id
  internet_security_enabled = true
}

resource "azurerm_virtual_hub_connection" "vnet-eastasia-2-connection" {
  name                = "vnet-eastasia-2-connection"
  virtual_hub_id      = azurerm_virtual_hub.vhub-eastasia.id
  remote_virtual_network_id = azurerm_virtual_network.vnet-vwan-eastasia-2.id
  internet_security_enabled = true
}

resource "azurerm_virtual_hub_connection" "vnet-australiaeast-1-connection" {
  name                = "vnet-australiaeast-1-connection"
  virtual_hub_id      = azurerm_virtual_hub.vhub-australiaeast.id
  remote_virtual_network_id = azurerm_virtual_network.vnet-vwan-australiaeast-1.id
  internet_security_enabled = true
}

# Create EA Test VM 1
## Create NIC
resource "azurerm_network_interface" "nic-ea-vm-app-1" {
  name                = "nic-ea-vm-app-1-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name

  ip_configuration {
    name                          = "vm-nic-configuration"
    subnet_id                     = azurerm_subnet.subnet-vwan-vnet1-eastasia-1.id
    private_ip_address_allocation = "Dynamic"
  }
}

## Create VM
resource "azurerm_virtual_machine" "ea-vm-app-1" {
  name                  = "ea-vm-app-1-${var.environment}"
  location              = azurerm_resource_group.rg-vwan.location
  resource_group_name   = azurerm_resource_group.rg-vwan.name
  network_interface_ids = [azurerm_network_interface.nic-ea-vm-app-1.id]
  vm_size               = "Standard_B4as_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Create EA Test VM 2
## Create NIC
resource "azurerm_network_interface" "nic-ea-vm-app-2" {
  name                = "nic-ea-vm-app-2-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name

  ip_configuration {
    name                          = "vm-nic-configuration"
    subnet_id                     = azurerm_subnet.subnet-vwan-vnet2-eastasia-1.id
    private_ip_address_allocation = "Dynamic"
  }
}

## Create VM
resource "azurerm_virtual_machine" "ea-vm-app-2" {
  name                  = "ea-vm-app-2-${var.environment}"
  location              = azurerm_resource_group.rg-vwan.location
  resource_group_name   = azurerm_resource_group.rg-vwan.name
  network_interface_ids = [azurerm_network_interface.nic-ea-vm-app-2.id]
  vm_size               = "Standard_B4as_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Create AE Test VM 1
## Create NIC
resource "azurerm_network_interface" "nic-ae-vm-app-1" {
  name                = "nic-ae-vm-app-1-${var.environment}"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg-vwan.name

  ip_configuration {
    name                          = "vm-nic-configuration"
    subnet_id                     = azurerm_subnet.subnet-vwan-vnet1-australiaeast-1.id
    private_ip_address_allocation = "Dynamic"
  }
}

## Create VM
resource "azurerm_virtual_machine" "ae-vm-app-1" {
  name                  = "ae-vm-app-1-${var.environment}"
  location              = "australiaeast"
  resource_group_name   = azurerm_resource_group.rg-vwan.name
  network_interface_ids = [azurerm_network_interface.nic-ae-vm-app-1.id]
  vm_size               = "Standard_B4as_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
