---
type: official_reference
tool: terraform-google
authority: external_reference
---

# google_compute_region_url_map (list)

Lists [`google_compute_region_url_map`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_compute_region_url_map) resources for use with [`terraform query`](https://developer.hashicorp.com/terraform/cli/commands/query) and **`.tfquery.hcl`** files.

For how list resources work in this provider, file layout, Terraform version requirements, and shared `list` block arguments, refer to the guide [Use list resources with terraform query (Google Cloud provider)](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_list_resources_with_terraform_query).

## Example

```hcl
list "google_compute_region_url_map" "all" {
  provider = google

  config {
    region = "..." # Optional
    project = "..." # Optional
  }
}
```

Run `terraform query` from the directory that contains the `.tfquery.hcl` file.

## Configuration (`config` block)
* `region` - (Optional) The Region in which the url map should reside.
If it is not provided, the provider region is used.

* `project` - (Optional)

## Results

By default each result includes **resource identity** for [`google_compute_region_url_map`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_compute_region_url_map) (see [Resource identity](https://developer.hashicorp.com/terraform/language/block/import#identity)).

With `include_resource = true` on the `list` block, results also include the full resource-style attributes documented for the managed [`google_compute_region_url_map` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_compute_region_url_map#attributes-reference).
