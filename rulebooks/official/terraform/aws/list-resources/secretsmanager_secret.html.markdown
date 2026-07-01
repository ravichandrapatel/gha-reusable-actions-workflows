---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_secretsmanager_secret

Lists Secrets Manager Secret resources.

## Example Usage

```terraform
list "aws_secretsmanager_secret" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
