---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_glue_catalog

Lists Glue Catalog resources.

## Example Usage

```terraform
list "aws_glue_catalog" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
