---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_eks_cluster

Lists EKS (Elastic Kubernetes) Cluster resources.

## Example Usage

```terraform
list "aws_eks_cluster" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
