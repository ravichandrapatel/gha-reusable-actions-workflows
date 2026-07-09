---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_scheduler_schedule

Lists EventBridge Scheduler Schedule resources.

## Example Usage

```terraform
list "aws_scheduler_schedule" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
