# ---------- Backend Load Balancer (internal, sits in snet-app) ----------

resource "azurerm_lb" "backend" {
  name                = "lb-backend"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "lb-backend-frontend-ip"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "backend" {
  loadbalancer_id = azurerm_lb.backend.id
  name            = "backend-pool"
}

resource "azurerm_lb_probe" "backend_health" {
  loadbalancer_id     = azurerm_lb.backend.id
  name                = "backend-health-probe"
  protocol            = "Http"
  port                = 5000
  request_path        = "/health"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "backend_http" {
  loadbalancer_id                = azurerm_lb.backend.id
  name                           = "backend-http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 5000
  backend_port                   = 5000
  frontend_ip_configuration_name = "lb-backend-frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend.id]
  probe_id                       = azurerm_lb_probe.backend_health.id
}

# ---------- Frontend Load Balancer (internal, sits in snet-web) ----------
# App Gateway points here, not directly at the VMSS instances, so autoscale
# events don't break anything upstream.

resource "azurerm_lb" "frontend" {
  name                = "lb-frontend"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "lb-frontend-frontend-ip"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "frontend" {
  loadbalancer_id = azurerm_lb.frontend.id
  name            = "frontend-pool"
}

resource "azurerm_lb_probe" "frontend_health" {
  loadbalancer_id     = azurerm_lb.frontend.id
  name                = "frontend-health-probe"
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "frontend_http" {
  loadbalancer_id                = azurerm_lb.frontend.id
  name                           = "frontend-http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb-frontend-frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  probe_id                       = azurerm_lb_probe.frontend_health.id
}
