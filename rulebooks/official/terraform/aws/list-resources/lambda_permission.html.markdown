---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_lambda_permission

Lists Lambda permissions for a function.

## Example Usage

```terraform
list "aws_lambda_permission" "example" {
  provider = aws
  config {
    function_name = aws_lambda_function.example.function_name
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `function_name` - (Required) Name or ARN of the Lambda function.
* `qualifier` - (Optional) Function version or alias name.
* `region` - (Optional) Region to query. Defaults to provider region.
