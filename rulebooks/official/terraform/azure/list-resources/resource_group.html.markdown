---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_resource_group

Lists Resource Group resources.

## Example Usage

### List all Resource Groups in the subscription

```hcl
list "azurerm_resource_group" "example" {
  provider = azurerm
  config {}
}
```

### List all Resource Groups in the subscription matching a filter 

```hcl
list "azurerm_resource_group" "example" {
  provider = azurerm
  config {
    filter = "tagName eq 'terraform' and tagValue eq 'example'"
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `subscription_id` - (Optional) The ID of the subscription to query. Defaults to the value specified in the Provider Configuration.

* `filter` - (Optional) A filter expression to filter the results by.
