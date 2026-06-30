---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_lambda_function

Lists Lambda Function resources.

## Example Usage

```terraform
list "aws_lambda_function" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
