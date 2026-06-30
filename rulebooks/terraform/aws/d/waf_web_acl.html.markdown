---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# Data Source: aws_waf_web_acl

`aws_waf_web_acl` Retrieves a WAF Web ACL Resource Id.

## Example Usage

```terraform
data "aws_waf_web_acl" "example" {
  name = "tfWAFWebACL"
}
```

## Argument Reference

This data source supports the following arguments:

* `name` - (Required) Name of the WAF Web ACL.

## Attribute Reference

This data source exports the following attributes in addition to the arguments above:

* `id` - ID of the WAF Web ACL.
