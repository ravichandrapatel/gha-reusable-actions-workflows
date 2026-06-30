---
type: official_reference
tool: terraform-google
authority: external_reference
---

# google_sql_database (list)

Lists [`google_sql_database`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_sql_database) resources for use with [`terraform query`](https://developer.hashicorp.com/terraform/cli/commands/query) and **`.tfquery.hcl`** files.

For how list resources work in this provider, file layout, Terraform version requirements, and shared `list` block arguments, refer to the guide [Use list resources with terraform query (Google Cloud provider)](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_list_resources_with_terraform_query).

## Example

```hcl
list "google_sql_database" "all" {
  provider = google

  config {
    instance = "..."
    project = "..." # Optional
  }
}
```

Run `terraform query` from the directory that contains the `.tfquery.hcl` file.

## Configuration (`config` block)
* `instance` - (Required) The name of the Cloud SQL instance. This does not include the project
ID.

* `project` - (Optional)

## Results

By default each result includes **resource identity** for [`google_sql_database`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_sql_database) (see [Resource identity](https://developer.hashicorp.com/terraform/language/block/import#identity)).

With `include_resource = true` on the `list` block, results also include the full resource-style attributes documented for the managed [`google_sql_database` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_sql_database#attributes-reference).
