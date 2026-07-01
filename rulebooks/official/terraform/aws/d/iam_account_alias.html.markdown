---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# Data Source: aws_iam_account_alias

The IAM Account Alias data source allows access to the account alias
for the effective account in which Terraform is working.

## Example Usage

```terraform
data "aws_iam_account_alias" "current" {}

output "account_alias" {
  value = data.aws_iam_account_alias.current.account_alias
}
```

## Argument Reference

This data source does not support any arguments.

## Attribute Reference

This data source exports the following attributes in addition to the arguments above:

* `account_alias` - Alias associated with the AWS account.
* `id` - Alias associated with the AWS account.
