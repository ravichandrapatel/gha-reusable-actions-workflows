---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_kms_alias

Lists KMS aliases.

## Example Usage

```terraform
list "aws_kms_alias" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
