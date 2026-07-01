---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_signalr_service

Lists SignalR Service resources.

## Example Usage

### List all SignalR Service resources in the subscription

```hcl
list "azurerm_signalr_service" "example" {
  provider = azurerm
  config {}
}
```

### List all SignalR Service resources in a specific resource group

```hcl
list "azurerm_signalr_service" "example" {
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
