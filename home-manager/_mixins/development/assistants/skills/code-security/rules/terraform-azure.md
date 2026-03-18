---
title: Secure Azure Terraform Configurations
impact: HIGH
impactDescription: Cloud misconfigurations and data exposure
tags: security, terraform, azure, infrastructure, iac, storage, keyvault
---

## Secure Azure Terraform Configurations

Security best practices for Azure infrastructure via Terraform. Misconfigurations can lead to data breaches and unauthorized access.

### Storage Account Security

**Incorrect:**
```hcl
resource "azurerm_storage_account" "bad" {
  name                      = "storageaccountname"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  min_tls_version           = "TLS1_0"
  enable_https_traffic_only = false
}

resource "azurerm_storage_container" "bad" {
  name                  = "vhds"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "blob"
}
```

**Correct:**
```hcl
resource "azurerm_storage_account" "good" {
  name                      = "storageaccountname"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  min_tls_version           = "TLS1_2"
  enable_https_traffic_only = true
  network_rules {
    default_action             = "Deny"
    ip_rules                   = ["100.0.0.1"]
    virtual_network_subnet_ids = [azurerm_subnet.example.id]
    bypass                     = ["Metrics", "AzureServices"]
  }
}

resource "azurerm_storage_container" "good" {
  name                  = "vhds"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}
```

### App Service Security

**Incorrect:**
```hcl
resource "azurerm_app_service" "bad" {
  name                     = "example-app-service"
  location                 = azurerm_resource_group.example.location
  resource_group_name      = azurerm_resource_group.example.name
  app_service_plan_id      = azurerm_app_service_plan.example.id
  https_only               = false
  remote_debugging_enabled = true
  site_config {
    min_tls_version = "1.0"
    cors { allowed_origins = ["*"] }
  }
  auth_settings { enabled = false }
}
```

**Correct:**
```hcl
resource "azurerm_app_service" "good" {
  name                     = "example-app-service"
  location                 = azurerm_resource_group.example.location
  resource_group_name      = azurerm_resource_group.example.name
  app_service_plan_id      = azurerm_app_service_plan.example.id
  https_only               = true
  remote_debugging_enabled = false
  site_config {
    min_tls_version = "1.2"
    cors { allowed_origins = ["https://example.com"] }
  }
  auth_settings { enabled = true }
}
```

### Key Vault Security

**Incorrect:**
```hcl
resource "azurerm_key_vault" "bad" {
  name                     = "examplekeyvault"
  location                 = azurerm_resource_group.example.location
  purge_protection_enabled = false
  network_acls { bypass = "AzureServices"; default_action = "Allow" }
}

resource "azurerm_key_vault_key" "bad" {
  name         = "mykey"
  key_vault_id = azurerm_key_vault.example.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
}
```

**Correct:**
```hcl
resource "azurerm_key_vault" "good" {
  name                       = "examplekeyvault"
  location                   = azurerm_resource_group.example.location
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  network_acls { bypass = "AzureServices"; default_action = "Deny" }
}

resource "azurerm_key_vault_key" "good" {
  name            = "mykey"
  key_vault_id    = azurerm_key_vault.example.id
  key_type        = "RSA"
  key_size        = 2048
  expiration_date = "2025-12-31T00:00:00Z"
  key_opts        = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
}
```

### Database Security

**Incorrect:**
```hcl
resource "azurerm_mssql_server" "bad" {
  name                          = "mssqlserver"
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  version                       = "12.0"
  minimum_tls_version           = "1.0"
  public_network_access_enabled = true
}

resource "azurerm_mysql_firewall_rule" "bad" {
  name             = "office"
  server_name      = azurerm_mysql_server.example.name
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}
```

**Correct:**
```hcl
resource "azurerm_mssql_server" "good" {
  name                          = "mssqlserver"
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = "00000000-0000-0000-0000-000000000000"
  }
}

resource "azurerm_mysql_firewall_rule" "good" {
  name             = "office"
  server_name      = azurerm_mysql_server.example.name
  start_ip_address = "40.112.8.12"
  end_ip_address   = "40.112.8.17"
}
```

### AKS Security

**Incorrect:**
```hcl
resource "azurerm_kubernetes_cluster" "bad" {
  name                            = "example-aks1"
  location                        = azurerm_resource_group.example.location
  resource_group_name             = azurerm_resource_group.example.name
  dns_prefix                      = "exampleaks1"
  private_cluster_enabled         = false
  api_server_authorized_ip_ranges = []
  default_node_pool { name = "default"; node_count = 1; vm_size = "Standard_D2_v2" }
  identity { type = "SystemAssigned" }
}
```

**Correct:**
```hcl
resource "azurerm_kubernetes_cluster" "good" {
  name                            = "example-aks1"
  location                        = azurerm_resource_group.example.location
  resource_group_name             = azurerm_resource_group.example.name
  dns_prefix                      = "exampleaks1"
  private_cluster_enabled         = true
  disk_encryption_set_id          = azurerm_disk_encryption_set.example.id
  api_server_authorized_ip_ranges = ["192.168.0.0/16"]
  default_node_pool { name = "default"; node_count = 1; vm_size = "Standard_D2_v2" }
  identity { type = "SystemAssigned" }
}
```

### VM Scale Sets

**Incorrect:**
```hcl
resource "azurerm_linux_virtual_machine_scale_set" "bad" {
  name                            = "example-vmss"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  sku                             = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@55w0rd1234!"
  encryption_at_host_enabled      = false
  disable_password_authentication = false
}
```

**Correct:**
```hcl
resource "azurerm_linux_virtual_machine_scale_set" "good" {
  name                            = "example-vmss"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  sku                             = "Standard_F2"
  admin_username                  = "adminuser"
  encryption_at_host_enabled      = true
  disable_password_authentication = true
  admin_ssh_key { username = "adminuser"; public_key = tls_private_key.new.public_key_pem }
}
```

### Public Network Access and Network Isolation

Always disable public network access and use virtual networks where possible.

**Incorrect:**
```hcl
resource "azurerm_cosmosdb_account" "bad" {
  name                          = "tfex-cosmos-db"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  public_network_access_enabled = true
}

resource "azurerm_container_group" "bad" {
  name                = "example-continst"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  ip_address_type     = "public"
  os_type             = "Linux"
  container { name = "hello-world"; image = "microsoft/aci-helloworld:latest"; cpu = "0.5"; memory = "1.5" }
}
```

**Correct:**
```hcl
resource "azurerm_cosmosdb_account" "good" {
  name                          = "tfex-cosmos-db"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  public_network_access_enabled = false
  key_vault_key_id              = azurerm_key_vault_key.example.versionless_id
}

resource "azurerm_container_group" "good" {
  name                = "example-continst"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  ip_address_type     = "private"
  os_type             = "Linux"
  network_profile_id  = azurerm_network_profile.example.id
  container { name = "hello-world"; image = "microsoft/aci-helloworld:latest"; cpu = "0.5"; memory = "1.5" }
}
```

### IAM - Custom Roles

**Incorrect:**
```hcl
resource "azurerm_role_definition" "bad" {
  name  = "my-custom-role"
  scope = data.azurerm_subscription.primary.id
  permissions { actions = ["*"]; not_actions = [] }
  assignable_scopes = [data.azurerm_subscription.primary.id]
}
```

**Correct:**
```hcl
resource "azurerm_role_definition" "good" {
  name  = "my-custom-role"
  scope = data.azurerm_subscription.primary.id
  permissions {
    actions = [
      "Microsoft.Authorization/*/read",
      "Microsoft.Insights/alertRules/*",
      "Microsoft.Resources/deployments/write",
      "Microsoft.Support/*"
    ]
    not_actions = []
  }
  assignable_scopes = [data.azurerm_subscription.primary.id]
}
```
