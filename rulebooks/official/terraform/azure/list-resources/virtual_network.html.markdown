---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_virtual_network

Lists Virtual Network resources.

## Example Usage

```hcl
list "azurerm_virtual_network" "example" {
  provider = azurerm
  config {
    resource_group_name = "example-rg"
  }
}
```

## Argument Reference

This list resource supports the following attributes:

* `resource_group_name` - (Required) The name of the resource group to query.
