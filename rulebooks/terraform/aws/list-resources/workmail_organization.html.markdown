---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_workmail_organization

Lists WorkMail Organization resources.

## Example Usage

```terraform
list "aws_workmail_organization" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
