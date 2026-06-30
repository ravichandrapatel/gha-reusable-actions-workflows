---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_ecs_daemon_task_definition

Lists ECS (Elastic Container) Daemon Task Definition resources.

## Example Usage

```terraform
list "aws_ecs_daemon_task_definition" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
