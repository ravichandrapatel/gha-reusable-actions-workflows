---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_pinpointsmsvoicev2_event_destination

Lists AWS End User Messaging SMS Event Destination resources.

## Example Usage

```terraform
list "aws_pinpointsmsvoicev2_event_destination" "example" {
  provider = aws

  config {
    configuration_set_names = ["my-configuration-set"]
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `configuration_set_names` - (Required) Names of configuration sets to list event destinations for.
* `region` - (Optional) Region to query. Defaults to provider region.
