# ---------- Backend VMSS (Flask) ----------

resource "azurerm_linux_virtual_machine_scale_set" "backend" {
  name                = "vmss-backend"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard_D2s_v3"
  instances           = 1
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching               = "ReadWrite"
  }

  network_interface {
    name    = "nic-backend"
    primary = true

    ip_configuration {
      name                                   = "ipconfig-backend"
      primary                                = true
      subnet_id                              = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend.id]
    }
  }

  custom_data = filebase64("${path.module}/../scripts/vmss-cloud-init-backend.yaml")

  identity {
    type = "SystemAssigned"
  }
}

# Note: the two Key Vault secrets (mysql-admin-password, mysql-host) must
# already exist before this VMSS boots, since fetch_secrets.py reads them
# at cloud-init time. You already created both manually via Cloud Shell,
# so this is just a reminder for next time, not something Terraform enforces.

# Grants the backend VMSS's Managed Identity permission to read secrets —
# this is what fetch_secrets.py relies on at boot.
resource "azurerm_role_assignment" "backend_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.backend.identity[0].principal_id
}

# ---------- Frontend VMSS (Nginx) ----------

resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
  name                = "vmss-frontend"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard_D2s_v3"
  instances           = 1
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching               = "ReadWrite"
  }

  network_interface {
    name    = "nic-frontend"
    primary = true

    ip_configuration {
      name                                   = "ipconfig-frontend"
      primary                                = true
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend.id]
    }
  }

  # backend_lb_ip is filled in automatically — the frontend's Nginx config
  # needs to know where to proxy /api/ requests to.
  custom_data = base64encode(templatefile(
    "${path.module}/../scripts/vmss-cloud-init-frontend.yaml.tpl",
    {
      backend_lb_ip = azurerm_lb.backend.frontend_ip_configuration[0].private_ip_address
    }
  ))

  identity {
    type = "SystemAssigned"
  }
}

# ---------- Autoscale (frontend only, for now) ----------

resource "azurerm_monitor_autoscale_setting" "frontend" {
  name                = "autoscale-frontend"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.frontend.id

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
