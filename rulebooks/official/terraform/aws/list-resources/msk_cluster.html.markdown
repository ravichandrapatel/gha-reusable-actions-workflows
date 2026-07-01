---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_msk_cluster

Lists Managed Streaming for Kafka Cluster resources.

## Example Usage

```terraform
list "aws_msk_cluster" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
