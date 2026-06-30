---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# Data Source: aws_oam_sinks

Terraform data source for managing an AWS CloudWatch Observability Access Manager Sinks.

## Example Usage

### Basic Usage

```terraform
data "aws_oam_sinks" "example" {
}
```

## Argument Reference

This data source supports the following arguments:

* `region` - (Optional) Region where this resource will be [managed](https://docs.aws.amazon.com/general/latest/gr/rande.html#regional-endpoints). Defaults to the Region set in the [provider configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#aws-configuration-reference).

## Attribute Reference

This data source exports the following attributes in addition to the arguments above:

* `arns` - Set of ARN of the Sinks.
