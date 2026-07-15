resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.5.0/24"]
}

resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-jobtrackr"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "jobtrackr-atharva"
}

resource "azurerm_network_security_rule" "web_allow_http" {
  name                        = "Allow-HTTP-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-policy-jobtrackr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "main" {
  name                = "appgw-jobtrackr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # --- HTTP (port 80) ---

  frontend_port {
    name = "port-80"
    port = 80
  }

  http_listener {
    name                           = "appgw-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "appgw-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-http-settings"
    priority                   = 100
  }

  # --- HTTPS (port 443) ---

ssl_certificate {
  name     = "appgw-real-cert"
  data     = filebase64("${path.module}/jobtrackr-real.pfx")
  password = "JobTrackrCert2026!"
}

  frontend_port {
    name = "port-443"
    port = 443
  }

http_listener {
  name                           = "appgw-https-listener"
  frontend_ip_configuration_name = "appgw-frontend-ip"
  frontend_port_name             = "port-443"
  protocol                       = "Https"
  ssl_certificate_name           = "appgw-real-cert"
}

  request_routing_rule {
    name                       = "appgw-https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-https-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-http-settings"
    priority                   = 90
  }


  backend_address_pool {
    name = "appgw-backend-pool"
    ip_addresses = [
      azurerm_lb.frontend.frontend_ip_configuration[0].private_ip_address
    ]
  }

  backend_http_settings {
    name                   = "appgw-http-settings"
    cookie_based_affinity  = "Disabled"
    port                   = 80
    protocol               = "Http"
    request_timeout        = 20
  }

  identity {
  type         = "UserAssigned"
  identity_ids = ["/subscriptions/f499cfc9-f0a4-4994-9fdc-03ed098789ad/resourceGroups/rg-jobtrackr-persistent/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-appgw-cert-reader"]
}
}