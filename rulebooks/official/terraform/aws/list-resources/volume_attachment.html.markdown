---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_volume_attachment

Lists EBS Volume Attachment resources.

## Example Usage

```terraform
list "aws_volume_attachment" "example" {
  config {
    instance_id = aws_instance.example.id
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `instance_id` - (Required) ID of the EC2 Instance to list volume attachments for.
* `region` - (Optional) Region to query. Defaults to provider region.
