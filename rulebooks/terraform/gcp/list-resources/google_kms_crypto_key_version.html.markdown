---
type: official_reference
tool: terraform-google
authority: external_reference
---

# google_kms_crypto_key_version (list)

Lists [`google_kms_crypto_key_version`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_kms_crypto_key_version) resources for use with [`terraform query`](https://developer.hashicorp.com/terraform/cli/commands/query) and **`.tfquery.hcl`** files.

For how list resources work in this provider, file layout, Terraform version requirements, and shared `list` block arguments, refer to the guide [Use list resources with terraform query (Google Cloud provider)](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_list_resources_with_terraform_query).

## Example

```hcl
list "google_kms_crypto_key_version" "all" {
  provider = google

  config {
    crypto_key = "..."
  }
}
```

Run `terraform query` from the directory that contains the `.tfquery.hcl` file.

## Configuration (`config` block)
* `crypto_key` - (Required) The name of the cryptoKey associated with the CryptoKeyVersions.
Format: `'projects/{{project}}/locations/{{location}}/keyRings/{{keyring}}/cryptoKeys/{{cryptoKey}}'`


## Results

By default each result includes **resource identity** for [`google_kms_crypto_key_version`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_kms_crypto_key_version) (see [Resource identity](https://developer.hashicorp.com/terraform/language/block/import#identity)).

With `include_resource = true` on the `list` block, results also include the full resource-style attributes documented for the managed [`google_kms_crypto_key_version` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_kms_crypto_key_version#attributes-reference).
