---
type: official_reference
tool: terraform-google
authority: external_reference
---

# google_storage_control_folder_intelligence_config

Get information about a Cloud Storage Control FolderIntelligenceConfig.



## Example Usage

```hcl
data "google_storage_control_folder_intelligence_config" "default" {
  name = google_storage_control_folder_intelligence_config.example.name
}
```

## Argument Reference

The following arguments are supported:



* `name` -
  (Required)
  Identifier of the GCP Folder. For GCP Folder, this field can be folder number.



## Attributes Reference

See [google_storage_control_folder_intelligence_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_control_folder_intelligence_config#argument-reference) resource for details of the available attributes.
