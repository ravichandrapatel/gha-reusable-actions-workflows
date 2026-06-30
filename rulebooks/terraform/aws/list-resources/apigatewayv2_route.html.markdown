---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_apigatewayv2_route

Lists API Gateway V2 Route resources.

## Example Usage

```terraform
list "aws_apigatewayv2_route" "example" {
  provider = aws

  config {
    api_id = aws_apigatewayv2_api.example.id
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `api_id` - (Required) API identifier.
* `region` - (Optional) Region to query. Defaults to provider region.
