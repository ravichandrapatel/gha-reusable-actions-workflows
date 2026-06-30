---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# Data Source: aws_waf_rule

`aws_waf_rule` Retrieves a WAF Rule Resource Id.

## Example Usage

```terraform
data "aws_waf_rule" "example" {
  name = "tfWAFRule"
}

```

## Argument Reference

This data source supports the following arguments:

* `name` - (Required) Name of the WAF rule.

## Attribute Reference

This data source exports the following attributes in addition to the arguments above:

* `id` - ID of the WAF rule.
