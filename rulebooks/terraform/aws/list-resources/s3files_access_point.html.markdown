---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_s3files_access_point

Lists S3 Files Access Point resources.

## Example Usage

```terraform
list "aws_s3files_access_point" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
