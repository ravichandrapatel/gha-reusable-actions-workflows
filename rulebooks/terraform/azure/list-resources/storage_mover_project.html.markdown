---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_storage_mover_project

Lists Storage Mover Project resources.

## Example Usage

### List Projects in a Storage Mover

```hcl
list "azurerm_storage_mover_project" "example" {
  provider = azurerm
  config {
    storage_mover_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.StorageMover/storageMovers/example-mover"
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `storage_mover_id` - (Required) The ID of the Storage Mover to query.
