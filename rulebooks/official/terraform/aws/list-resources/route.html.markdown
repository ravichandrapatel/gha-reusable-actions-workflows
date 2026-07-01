---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_route

Lists routes in a route table.

## Example Usage

```terraform
list "aws_route" "example" {
  provider = aws

  config {
    route_table_id = aws_route_table.example.id
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
* `route_table_id` - (Required) ID of the route table.
