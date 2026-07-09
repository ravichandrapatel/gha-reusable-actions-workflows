---
type: official_reference
tool: terraform-azurerm
authority: external_reference
---

# List resource: azurerm_cognitive_account_connection_account_key

Lists Cognitive Services Account Connection with Account Key authentication resources.

## Example Usage
```hcl
data "azurerm_cognitive_account" "example" {
  name                = "example-account"
  resource_group_name = "example-resources"
}

list "cognitive_account_connection_account_key" "example" {
  provider = azurerm
  config {
    cognitive_account_id = data.azurerm_cognitive_account.example.id
  }
}
```
## Argument Reference
This list resource supports the following arguments:
* `cognitive_account_id` - (Required) The ID of the Cognitive Account to query.
