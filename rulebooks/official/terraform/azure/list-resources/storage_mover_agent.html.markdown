---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_storage_mover_agent

Lists Storage Mover Agent resources.

## Example Usage

### List Agents in a Storage Mover

```hcl
list "azurerm_storage_mover_agent" "example" {
  provider = azurerm
  config {
    storage_mover_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.StorageMover/storageMovers/example-mover"
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `storage_mover_id` - (Required) The ID of the Storage Mover to query.
