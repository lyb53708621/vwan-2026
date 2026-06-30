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
resource "azurerm_vpn_gateway" "vwan-gateway-eastasia" {
  name                = "vwan-gateway-eastasia-${var.environment}"
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

resource "azurerm_firewall_policy_rule_collection_group" "fwrcg" {
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
      destination_fqdns = ["*.microsoft.com"]
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

# Create Network Resources
## Create NSG
resource "azurerm_network_security_group" "nsg-vwan-eastasia-1" {
  name                = "nsg-vwan-${var.environment}-eastasia-1"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
}

## Create VNET
resource "azurerm_virtual_network" "vnet-vwan-eastasia-1" {
  name                = "vnet-vwan-${var.environment}-eastasia-1"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.rg-vwan.name
  address_space       = var.address_space

  tags = var.tags
}

## Create Subnet
resource "azurerm_subnet" "subnet-vwan-eastasia-1" {
  name                 = "app-subnet-1"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-eastasia-1.name
  address_prefixes     = var.address_prefixes_1
}

resource "azurerm_subnet" "subnet-vwan-eastasia-2" {
  name                 = "db-subnet-1"
  resource_group_name = azurerm_resource_group.rg-vwan.name
  virtual_network_name = azurerm_virtual_network.vnet-vwan-eastasia-1.name
  address_prefixes     = var.address_prefixes_2
}

## Associate NSG to Subnet
resource "azurerm_subnet_network_security_group_association" "subnet-1-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-eastasia-1.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-eastasia-1.id

  depends_on = [
    azurerm_subnet.subnet-vwan-eastasia-1,
    azurerm_network_security_group.nsg-vwan-eastasia-1
  ]

}

resource "azurerm_subnet_network_security_group_association" "subnet-2-assoc" {
  subnet_id                 = azurerm_subnet.subnet-vwan-eastasia-2.id
  network_security_group_id = azurerm_network_security_group.nsg-vwan-eastasia-1.id

  depends_on = [
    azurerm_subnet.subnet-vwan-eastasia-2,
    azurerm_network_security_group.nsg-vwan-eastasia-1
  ]
}

## VNET Connection to VWAN Hub
resource "azurerm_virtual_hub_connection" "vnet-eastasia-1-connection" {
  name                = "vnet-eastasia-1-connection"
  virtual_hub_id      = azurerm_virtual_hub.vhub-eastasia.id
  remote_virtual_network_id = azurerm_virtual_network.vnet-vwan-eastasia-1.id
  internet_security_enabled = true
}


/**
# Create Test VM 1
## Create NIC
resource "azurerm_network_interface" "nic-vm-app-1" {
  name                = "nic-app-vm-1-${var.environment}"
  location            = azurerm_resource_group.rg-vwan.location
  resource_group_name = azurerm_resource_group.alz1.name

  ip_configuration {
    name                          = "vm-nic-configuration"
    subnet_id                     = azurerm_subnet.vnet-alz-1-subnet-1.id
    private_ip_address_allocation = "Dynamic"
  }
}

## Create VM
resource "azurerm_virtual_machine" "vm-app-1" {
  name                  = "vm-app-1-${var.environment}"
  location              = azurerm_resource_group.alz1.location
  resource_group_name   = azurerm_resource_group.alz1.name
  network_interface_ids = [azurerm_network_interface.nic-vm-app-1.id]
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
**/