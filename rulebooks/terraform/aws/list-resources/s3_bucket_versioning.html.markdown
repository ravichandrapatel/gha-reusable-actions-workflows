---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_s3_bucket_versioning

Lists S3 (Simple Storage) Bucket Versioning resources.

## Example Usage

```terraform
list "aws_s3_bucket_versioning" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
