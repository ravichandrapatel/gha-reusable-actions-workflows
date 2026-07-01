---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_securityhub_insight

Lists Security Hub Insight resources.

## Example Usage

```terraform
list "aws_securityhub_insight" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
