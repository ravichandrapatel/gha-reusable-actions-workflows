---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_cleanrooms_membership

Lists Clean Rooms Membership resources.

## Example Usage

```terraform
list "aws_cleanrooms_membership" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
