---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_web_pubsub_socketio

Lists Web PubSub Service for Socket.IO resources.

## Example Usage

### List all Web PubSub Service for Socket.IO resources in a Subscription

```hcl
list "azurerm_web_pubsub_socketio" "example" {
  provider = azurerm
  config {}
}
```

### List all Web PubSub Service for Socket.IO resources in a Resource Group

```hcl
list "azurerm_web_pubsub_socketio" "example" {
  provider = azurerm
  config {
    resource_group_name = azurerm_resource_group.example.name
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `subscription_id` - (Optional) The Subscription ID in which to list resources. Defaults to the current subscription.

* `resource_group_name` - (Optional) The Resource Group name in which to list resources.
