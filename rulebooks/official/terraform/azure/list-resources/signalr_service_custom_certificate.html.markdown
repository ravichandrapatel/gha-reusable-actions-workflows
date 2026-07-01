---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_signalr_service_custom_certificate

Lists SignalR Service Custom Certificate resources.

## Example Usage

### List SignalR Service Custom Certificates in a SignalR Service

```hcl
list "azurerm_signalr_service_custom_certificate" "example" {
  provider = azurerm
  config {
    signalr_service_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myresourcegroup/providers/Microsoft.SignalRService/signalR/mysignalr"
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `signalr_service_id` - (Required) The ID of the SignalR Service to query.
