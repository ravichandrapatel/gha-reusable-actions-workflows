---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_s3_bucket_logging

Lists S3 (Simple Storage) Bucket Logging resources.

## Example Usage

### Basic Usage

```terraform
list "aws_s3_bucket_logging" "example" {
  provider = aws
}
```

### Include Resource Data

```terraform
list "aws_s3_bucket_logging" "example" {
  provider = aws

  include_resource = true
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
