---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_public_ip

Lists Public Ip resources.

## Example Usage

### List all Public Ips in the subscription

```hcl
list "azurerm_public_ip" "example" {
  provider = azurerm
  config {
  }
}
```

### List all Public Ips in a Resource Group

```hcl
list "azurerm_public_ip" "example" {
  provider = azurerm
  config {
    resource_group_name = "example-rg"
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `subscription_id` - (Optional) The ID of the Subscription to query. Defaults to the value specified in the Provider Configuration.

* `resource_group_name` - (Optional) The name of the Resource Group to query.
