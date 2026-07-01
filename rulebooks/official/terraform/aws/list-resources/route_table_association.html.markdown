---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_route_table_association

Lists Route Table Association resources.

## Example Usage

```terraform
list "aws_route_table_association" "example" {
  provider = aws

  config {
    route_table_id = aws_route_table.example.id
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
* `route_table_id` - (Required) ID of owning Route Table.
