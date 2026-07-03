---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_ssoadmin_region

Lists SSO Admin Region resources.

## Example Usage

```terraform
list "aws_ssoadmin_region" "example" {
  provider = aws

  config {
    instance_arn = tolist(data.aws_ssoadmin_instances.example.arns)[0]
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `instance_arn` - (Required) ARN of the IAM Identity Center instance to list Regions from.
* `region` - (Optional) Region to query. Defaults to provider region.
