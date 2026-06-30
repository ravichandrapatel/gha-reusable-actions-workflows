---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_ec2_transit_gateway_metering_policy

Lists EC2 (Elastic Compute Cloud) Transit Gateway Metering Policy resources.

## Example Usage

```terraform
list "aws_ec2_transit_gateway_metering_policy" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
