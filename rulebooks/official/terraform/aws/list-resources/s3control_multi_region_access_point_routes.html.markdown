---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_s3control_multi_region_access_point_routes

Lists S3 Control Multi Region Access Point Routes resources.

## Example Usage

```terraform
list "aws_s3control_multi_region_access_point_routes" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
