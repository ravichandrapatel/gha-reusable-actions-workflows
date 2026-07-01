---
type: official_reference
tool: terraform-google
authority: external_reference
---

# google_iap_client

Get information about a Identity-Aware Proxy Client.



## Example Usage

```hcl
data "google_iap_client" "default" {
  brand = google_iap_client.project_client.brand
  client_id = google_iap_client.project_client.client_id
}
```

## Argument Reference

The following arguments are supported:



* `client_id` -
  Output only. Unique identifier of the OAuth client.

* `brand` -
  (Required)
  Identifier of the brand to which this client
  is attached to. The format is
  `projects/{project_number}/brands/{brand_id}`.



## Attributes Reference

See [google_iap_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_client#argument-reference) resource for details of the available attributes.
