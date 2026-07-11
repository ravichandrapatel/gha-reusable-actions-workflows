---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_sfn_state_machine

Lists SFN (Step Functions) State Machine resources.

## Example Usage

```terraform
list "aws_sfn_state_machine" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
