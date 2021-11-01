terraform {

   required_version = ">=0.12"

   required_providers {
     azurerm = {
       source = "hashicorp/azurerm"
       version = ">=2.0"
     }
   }
 }
#create Azure provider

 provider "azurerm" {
   features {}
 }

# create Azure Resource group 

 resource "azurerm_resource_group" "resourceGroup"{
   name     = "azrg"
   location = "West US 2"
 }

 resource "azurerm_virtual_network" "vnet" {
   name                = "azvn"
   address_space       = ["10.0.0.0/16"]
   location            = azurerm_resource_group.resourceGroup.location
   resource_group_name = azurerm_resource_group.resourceGroup.name
 }


resource "azurerm_network_security_group" "nsg" {
  name                = "aznsg"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  security_rule {
    name                       = "HTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
      name                       = "HTTP"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    } 
     tags {
    environment = "test"
  }
}
  
 resource "azurerm_subnet1" "subnet1"{
   name                 = "azsub1"
   resource_group_name  = azurerm_resource_group.resourceGroup.name
   virtual_network_name = azurerm_virtual_network.resourceGroup.name
   address_prefixes     = ["10.0.2.0/24"]
 }



 resource "azurerm_subnet2" "subnet2" {
   name                 = "azsub2"
   resource_group_name  = azurerm_resource_group.resourceGroup.name
   virtual_network_name = azurerm_virtual_network.resourceGroup.name
   address_prefixes     = ["10.0.7.0/24"]
 }
 resource "azurerm_public_ip" "myvm1publicip"{
   name                         = "publicIP1"
   location                     = azurerm_resource_group.resourceGroup.location
   resource_group_name          = azurerm_resource_group.resourceGroup.name
   ublic_ip_address_allocation = "Dynamic"
  idle_timeout_in_minutes      = 30
 }

resource "azurerm_public_ip" "myvm2publicip"{
   name                         = "publicIP2"
   location                     = azurerm_resource_group.resourceGroup.location
   resource_group_name          = azurerm_resource_group.resourceGroup.name
   ublic_ip_address_allocation = "Dynamic"
  idle_timeout_in_minutes      = 30
 }
 resource "azurerm_network_interface" "nic1"{
   name                = "aznic1"
   location            = azurerm_resource_group.resourceGroup.location
   resource_group_name = azurerm_resource_group.resourceGroup.name
   network_security_group_id = azurerm_network_security_group.nsg.id

   ip_configuration {
     name                          = "ipconfig1"
     subnet_id                     = azurerm_subnet1.subnet1.id
     private_ip_address_allocation = "dynamic"
     public_ip_address_id          = azurerm_public_ip.myvm1publicip.id
   }
 }

resource "azurerm_network_interface" "nic2"{
   name                = "aznic2"
   location            = azurerm_resource_group.resourceGroup.location
   resource_group_name = azurerm_resource_group.resourceGroup.name
   network_security_group_id = azurerm_network_security_group.nsg.id

   ip_configuration {
     name                          = "ipconfig2"
     subnet_id                     = azurerm_subnet2.subnet2.id
     private_ip_address_allocation = "dynamic"
     public_ip_address_id          = azurerm_public_ip.myvm2publicip.id
   }
 }

esource "azurerm_storage_account" "storageacc" {
  name                     = "azsa"
  resource_group_name      = azurerm_resource_group.resourceGroupname
  location                 = azurerm_resource_group.resourceGroup.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_storage_container" "storagecont" {
  name                  = "azsac"
  resource_group_name   = azurerm_resource_group.resourceGroupname.name
  storage_account_name  = azurerm_storage_account.storageacc.name
  container_access_type = "private"
}

resource "azurerm_managed_disk" "datadisk" {
  name                 = "azmd"
  location             = azurerm_resource_group.resourceGroup.location
  resource_group_name  = azurerm_resource_group.resourceGroupname.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

data "azurerm_key_vault" "keyvault"{
       name = "keyvaultname"
       resource_group_name ="mykeyvault"
   }

data "azurerm_key_vault_secret" "keyvaultsecret1" {
        name ="azadmin"
        key_vault_id = data.azurerm_key_vault.keyvault.id
    }
data "azurerm_key_vault_secret" "keyvaultsecret2" {
        name ="adminuser"
        key_vault_id = data.azurerm_key_vault.keyvault.id
    }

 resource "azurerm_windows_virtual_machine" "vm1"{
  name                = "azvmachine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "data.azurerm_key_vault_secret.keyvaultsecret2.value"
  network_interface_ids = [ 
    azurerm_network_interface.nic1.id ]

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "storageosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

 storage_data_disk {
    name            = azurerm_managed_disk.datadisk.name
    managed_disk_id = azurerm_managed_disk.datadisk.id
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = azurerm_managed_disk.datadisk.disk_size_gb
  }

    os_profile {
     computer_name  = "hostname"
     admin_username = "azadmin"
     admin_password = "data.azurerm_key_vault_secret.keyvaultsecret1.value"
   }

   os_profile_windows_config {
    enable_automatic_upgrades = true
    provision_vm_agent        = true
   }
 
 }

 resource "azurerm_windows_virtual_machine" "vm2"{
  name                = "azvmachine2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      =   "data.azurerm_key_vault_secret.keyvaultsecret2.value"
  network_interface_ids = [ 
    azurerm_network_interface.nic2.id ]

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "storageosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

 storage_data_disk {
    name            = azurerm_managed_disk.datadisk.name
    managed_disk_id = azurerm_managed_disk.datadisk.id
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = azurerm_managed_disk.datadisk.disk_size_gb
  }


azadmin
   os_profile {
     computer_name  = "hostname"
     admin_username = "azadmin"
     admin_password = "data.azurerm_key_vault_secret.keyvaultsecret1.value"
   }

   os_profile_windows_config {
    enable_automatic_upgrades = true
    provision_vm_agent        = true
   }

   
 }
