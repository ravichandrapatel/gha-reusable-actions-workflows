---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_cloudwatch_log_metric_filter

Lists CloudWatch Logs Metric Filter resources.

## Example Usage

```terraform
list "aws_cloudwatch_log_metric_filter" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
