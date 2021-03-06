# Defining the local variables
locals {
  publicIPAddressName  = lower(join("", ["var.vmName", "publicIP"]))
  networkInterfaceName = lower(join("", ["var.vmName", "netint"]))
  osDiskType           = "Standard_LRS"
  subnetAddressPrefix  = "10.1.0.0/24"
  addressPrefix        = "10.1.0.0/16"
  dnsLabelPrefix       = lower(join("", ["simplelinuxvm-", random_string.vmd.result]))
}

# Generate random string for DNS Prefix
resource "random_string" "vmd" {
  length  = 16
  special = "false"
}

# Resource Group
resource "azurerm_resource_group" "arg-01" {
  name     = var.resourceGroupName
  location = var.location
}

# Network interface with IP configuration
resource "azurerm_network_interface" "anic-01" {
  name                = local.networkInterfaceName
  resource_group_name = azurerm_resource_group.arg-01.name
  location            = azurerm_resource_group.arg-01.location
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.apip-01.id
    subnet_id                     = azurerm_subnet.as-01.id
  }
}

# Network security group with SSH allow rule
resource "azurerm_network_security_group" "ansg-01" {
  name                = var.networkSecurityGroupName
  resource_group_name = azurerm_resource_group.arg-01.name
  location            = azurerm_resource_group.arg-01.location
  security_rule {
    name                       = "SSH"
    priority                   = 1000
    access                     = "Allow"
    direction                  = "Inbound"
    destination_port_range     = "22"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "avn-01" {
  name                = var.virtualNetworkName
  resource_group_name = azurerm_resource_group.arg-01.name
  location            = azurerm_resource_group.arg-01.location
  address_space       = [local.addressPrefix]
}

# Subnet
resource "azurerm_subnet" "as-01" {
  name                                           = var.subnetName
  resource_group_name                            = azurerm_resource_group.arg-01.name
  virtual_network_name                           = azurerm_virtual_network.avn-01.name
  address_prefixes                               = [local.subnetAddressPrefix]
  enforce_private_link_endpoint_network_policies = true
  enforce_private_link_service_network_policies  = true
}

# Associate subnet and network security group 
resource "azurerm_subnet_network_security_group_association" "asnsga-01" {
  subnet_id                 = azurerm_subnet.as-01.id
  network_security_group_id = azurerm_network_security_group.ansg-01.id
}

# Public IP
resource "azurerm_public_ip" "apip-01" {
  name                    = local.publicIPAddressName
  resource_group_name     = azurerm_resource_group.arg-01.name
  location                = azurerm_resource_group.arg-01.location
  allocation_method       = "Dynamic"
  domain_name_label       = local.dnsLabelPrefix
  ip_version              = "IPV4"
  idle_timeout_in_minutes = "4"
  sku                     = "Basic"
}

# Create VM if authentication type is SSH
resource "azurerm_linux_virtual_machine" "avm-ssh-01" {
  count                 = var.authenticationType == "ssh" ? 1 : 0
  name                  = var.vmName
  resource_group_name   = azurerm_resource_group.arg-01.name
  location              = azurerm_resource_group.arg-01.location
  size                  = var.VmSize
  network_interface_ids = [azurerm_network_interface.anic-01.id]
  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.UbuntuOSVersion[0]
    version   = "latest"
  }
  admin_username                  = var.admin_username
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

# Create VM if authentication type is pwd
resource "azurerm_linux_virtual_machine" "avm-pwd-01" {
  count                 = var.authenticationType == "pwd" ? 1 : 0
  name                  = var.vmName
  resource_group_name   = azurerm_resource_group.arg-01.name
  location              = azurerm_resource_group.arg-01.location
  size                  = var.VmSize
  network_interface_ids = [azurerm_network_interface.anic-01.id]
  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.UbuntuOSVersion[0]
    version   = "latest"
  }
  admin_username                  = var.admin_username
  admin_password                  = var.adminPassword
  disable_password_authentication = false
}

## Output
# Username 
output "adminUsername" {
  value = var.admin_username
}

# Host FQDN 
output "hostname" {
  value = azurerm_public_ip.apip-01.fqdn
}
