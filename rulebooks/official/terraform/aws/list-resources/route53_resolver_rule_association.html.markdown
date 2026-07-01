---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_route53_resolver_rule_association

Lists Route 53 Resolver Rule Association resources.

## Example Usage

```terraform
list "aws_route53_resolver_rule_association" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
