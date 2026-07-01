---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_cloudwatch_log_s3_table_integration_source

Lists CloudWatch Logs S3 Table Integration Source resources.

## Example Usage

```terraform
list "aws_cloudwatch_log_s3_table_integration_source" "example" {
  provider = aws

  config {
    integration_arn = aws_observabilityadmin_s3_table_integration.example.arn
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `integration_arn` - (Required) ARN of the integration.
* `region` - (Optional) Region to query. Defaults to provider region.
