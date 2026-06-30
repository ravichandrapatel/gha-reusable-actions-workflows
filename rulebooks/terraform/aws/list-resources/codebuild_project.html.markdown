---
type: official_reference
tool: terraform-aws
authority: external_reference
---

# List Resource: aws_codebuild_project

Lists CodeBuild Project resources.

## Example Usage

```terraform
list "aws_codebuild_project" "example" {
  provider = aws
}
```

## Argument Reference

This list resource supports the following arguments:

* `region` - (Optional) Region to query. Defaults to provider region.
