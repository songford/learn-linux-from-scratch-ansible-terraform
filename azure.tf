terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  location = "eastasia"
  name = "myTFResourceGroup"
}

resource "azurerm_virtual_network" "vnet" {
  address_space = ["10.0.0.0/16"]
  location = "eastasia"
  name = "mfTFVnet"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name = "myTFSubnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name = "myTFNSG"
  location = "eastasia"
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "SSH"
    priority = 1001
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "publicip" {
  allocation_method = "Static"
  location = "eastasia"
  name = "myTFPublicIP"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "nic" {
  location = "eastasia"
  name = "myNIC"
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name = "myNICConfig"
    subnet_id = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = azurerm_public_ip.publicip.id
  }
}
resource "azurerm_linux_virtual_machine" "vm" {
  admin_username = var.admin_username
  location = "eastasia"
  name = "myTFVM"
  network_interface_ids = [azurerm_network_interface.nic.id]
  resource_group_name = azurerm_resource_group.rg.name
  size = "Standard_DS1_v2"
  admin_ssh_key {
    public_key = file("~/.ssh/azure.pub")
    username = var.admin_username
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching           = "ReadWrite"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = lookup(var.sku, var.location)
    version   = "latest"
  }
}

data "azurerm_public_ip" "ip" {
  name                = azurerm_public_ip.publicip.name
  resource_group_name = azurerm_linux_virtual_machine.vm.resource_group_name
  depends_on          = [azurerm_linux_virtual_machine.vm]
}

output "public_ip_address" {
  value = data.azurerm_public_ip.ip.ip_address
}