---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# Data Source: aws_iam_outbound_web_identity_federation

Use this data source to retrieve information about an AWS IAM (Identity & Access Management) Outbound Web Identity Federation.

## Example Usage

```terraform
data "aws_iam_outbound_web_identity_federation" "example" {}
```

## Argument Reference

This data source does not support any arguments.

## Attribute Reference

This data source exports the following attributes in addition to the arguments above:

* `issuer_identifier` - A unique issuer URL for your AWS account that hosts the OpenID Connect (OIDC) discovery endpoints.
