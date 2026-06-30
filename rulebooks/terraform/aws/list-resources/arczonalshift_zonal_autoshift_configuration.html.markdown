---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_arczonalshift_zonal_autoshift_configuration

Lists ARC (Application Recovery Controller) Zonal Shift Zonal Autoshift Configuration resources.

## Example Usage

```terraform
list "aws_arczonalshift_zonal_autoshift_configuration" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
