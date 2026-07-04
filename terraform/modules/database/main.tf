# Application DB password — generated, never in code. Injected into cloud-init and
# later into a Kubernetes Secret. Special set excludes quotes to stay SQL/shell safe.
resource "random_password" "app" {
  length           = 24
  special          = true
  override_special = "!#%*-_"
}

# VM admin password (VM has no public IP; this is only reachable from within the VNet).
resource "random_password" "vm_admin" {
  length           = 24
  special          = true
  override_special = "!#%*-_"
}

# Private DNS zone for internal names, resolvable only inside linked VNets.
resource "azurerm_private_dns_zone" "internal" {
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  name                  = "link-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# NIC in the private DB subnet — no public IP.
resource "azurerm_network_interface" "db" {
  name                = "nic-db-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.db_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "db" {
  name                            = "vm-db-${var.name_prefix}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = random_password.vm_admin.result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.db.id]
  tags                            = var.tags

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    db_name         = var.database_name
    db_user         = var.db_username
    db_password     = random_password.app.result
    aks_subnet_cidr = var.aks_subnet_cidr
    db_subnet_cidr  = var.db_subnet_cidr
  }))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# Private DNS A record: postgres.devops.internal -> the VM's private IP.
resource "azurerm_private_dns_a_record" "db" {
  name                = "postgres"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_network_interface.db.private_ip_address]
  tags                = var.tags
}
