---
type: official_reference
tool: terraform-google
authority: external_reference
---

# google_storage_control_organization_intelligence_config

Get information about a Cloud Storage Control OrganizationIntelligenceConfig.



## Example Usage

```hcl
data "google_storage_control_organization_intelligence_config" "default" {
  name = google_storage_control_organization_intelligence_config.example.name
}
```

## Argument Reference

The following arguments are supported:



* `name` -
  (Required)
  Identifier of the GCP Organization. For GCP org, this field should be organization number.



## Attributes Reference

See [google_storage_control_organization_intelligence_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_control_organization_intelligence_config#argument-reference) resource for details of the available attributes.
