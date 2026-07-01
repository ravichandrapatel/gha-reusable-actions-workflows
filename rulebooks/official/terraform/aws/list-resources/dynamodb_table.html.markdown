---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_dynamodb_table

Lists DynamoDB Table resources.

## Example Usage

```terraform
list "aws_dynamodb_table" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
