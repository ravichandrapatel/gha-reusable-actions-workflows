---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_codepipeline

Lists CodePipeline Pipeline resources.

## Example Usage

```terraform
list "aws_codepipeline" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
