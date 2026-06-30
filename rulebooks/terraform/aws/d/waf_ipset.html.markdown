---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# Data Source: aws_waf_ipset

`aws_waf_ipset` Retrieves a WAF IP Set Resource Id.

## Example Usage

```terraform
data "aws_waf_ipset" "example" {
  name = "tfWAFIPSet"
}
```

## Argument Reference

This data source supports the following arguments:

* `name` - (Required) Name of the WAF IP set.

## Attribute Reference

This data source exports the following attributes in addition to the arguments above:

* `id` - ID of the WAF IP set.
