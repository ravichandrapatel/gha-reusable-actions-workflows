---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_acm_certificate

Lists ACM (Certificate Manager) Certificate resources.

## Example Usage

```terraform
list "aws_acm_certificate" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
