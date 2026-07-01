---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_lb_listener

Lists ELB (Elastic Load Balancing) Listener resources.

## Example Usage

```terraform
list "aws_lb_listener" "example" {
  provider = aws

  config {
    load_balancer_arn = aws_lb.example.arn
  }
}
```

## Argument Reference

This list resource supports the following arguments:

* `load_balancer_arn` - (Required) ARN of the Load Balancer to list Listeners from.
* `region` - (Optional) Region to query. Defaults to provider region.
