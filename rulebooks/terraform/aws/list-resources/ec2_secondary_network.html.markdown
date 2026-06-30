---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_ec2_secondary_network

Lists EC2 (Elastic Compute Cloud) Secondary Network resources.

## Example Usage

```terraform
list "aws_ec2_secondary_network" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
