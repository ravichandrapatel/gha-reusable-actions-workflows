---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_mysql_flexible_database

Lists MySQL Flexible Server Database resources.

## Example Usage

### List all MySQL Databases deployed in a specific Flexible Server

```hcl
list "azurerm_mysql_flexible_database" "example" {
  provider = azurerm
  config {
    flexible_server_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/group1/providers/Microsoft.DBforMySQL/flexibleServers/flexibleServer1"
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `flexible_server_id` - (Required) The full ID of an existing Azure MySQL Flexible Server.

````
