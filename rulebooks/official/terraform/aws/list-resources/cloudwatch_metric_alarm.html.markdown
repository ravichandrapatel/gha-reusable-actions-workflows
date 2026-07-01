---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_cloudwatch_metric_alarm

Lists CloudWatch Metric Alarm resources.

## Example Usage

```terraform
list "aws_cloudwatch_metric_alarm" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
