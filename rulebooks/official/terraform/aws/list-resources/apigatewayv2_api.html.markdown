---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_apigatewayv2_api

Lists API Gateway V2 API resources.

## Example Usage

```terraform
list "aws_apigatewayv2_api" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
