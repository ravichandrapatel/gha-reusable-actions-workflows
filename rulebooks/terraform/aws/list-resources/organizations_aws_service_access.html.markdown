---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_organizations_aws_service_access

Lists Organizations AWS Service Access resources.

## Example Usage

```terraform
list "aws_organizations_aws_service_access" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
