---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_sqs_queue_policy

Lists SQS queue policies for queues in the configured region.

## Example Usage

```terraform
list "aws_sqs_queue_policy" "example" {
  provider = aws
}

list "aws_sqs_queue_policy" "example_with_resource_data" {
  provider = aws

  include_resource = true
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
