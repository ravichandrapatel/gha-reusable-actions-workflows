---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_config_remediation_configuration

Lists Config Remediation Configuration resources.

## Example Usage

```terraform
list "aws_config_remediation_configuration" "example" {
  provider = aws

  config_rule_names = ["example-rule-1", "example-rule-2"]
}
```

## Argument Reference

This list resource supports the following arguments:

* `config_rule_names` - (Required) Names of the AWS Config rules.
* `region` - (Optional) Region to query. Defaults to provider region.
