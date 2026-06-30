---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_eip

Lists EC2 (Elastic Compute Cloud) EIP resources.

## Example Usage

```terraform
list "aws_eip" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
