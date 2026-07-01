---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_redis_cache

Lists Redis Cache resources.

## Example Usage

### List all Redis Cache instances in the subscription

```hcl
list "azurerm_redis_cache" "example" {
  provider = azurerm
  config {}
}
```

### List all Redis Cache instances in a specific resource group

```hcl
list "azurerm_redis_cache" "example" {
  provider = azurerm
  config {
    resource_group_name = "example-rg"
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `resource_group_name` - (Optional) The name of the resource group to query.

* `subscription_id` - (Optional) The Subscription ID to query. Defaults to the value specified in the Provider Configuration.
````
