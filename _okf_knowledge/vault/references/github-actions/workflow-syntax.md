---
type: Reference
title: Workflow syntax for GitHub Actions
description: Cached upstream documentation, fetched by `okf.py scrape`.
tags: [github-actions, upstream, cached]
timestamp: "2026-07-27T20:32:01Z"
source_url: "https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions"
---

### Common Usage

**Official documentation:** [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

See [Standards index](/standards/index.md) for binding house rules.

### Syntax

Workflow syntax for GitHub Actions - GitHub Docs
Skip to main content
Collapse sidebar
…
# Workflow syntax for GitHub Actions
A workflow is a configurable automated process made up of one or more jobs. You must create a YAML file to define your workflow configuration.
Copy as Markdown
## In this article
## About YAML syntax for workflows
Workflow files use YAML syntax, and must have either a
.yml
or
…
## name
The name of the workflow. GitHub displays the names of your workflows under your repository's "Actions" tab. If you omit
name
, GitHub displays the workflow file path relative to the root of the repository.
## run-name
The name for workflow runs generated from the workflow. GitHub displays the workflow run name in the list of workflow runs on your repository's "Actions" tab. If
run-name
is omitted or is only whitespace, then the run name is set to event-specific information for the workflow run. For example, for a workflow triggered by a
…
### Example of
run-name
```
run-name:
…
## on
To automatically trigger a workflow, use
on
to define which events can cause the workflow to run. For a list of available events, see
…
### Using a single event
For example, a workflow with the following
on
value will run when a push is made to any branch in the workflow's repository:
…
### Using multiple events
You can specify a single event or multiple events. For example, a workflow with the following
on
value will run when a push is made to any branch in the repository or when someone forks the repository:
…
### Using activity types
Some events have activity types that give you more control over when your workflow should run. Use
on.<event_name>.types
to define the type of event activity that will trigger a workflow run.
…
### Using filters
Some events have filters that give you more control over when your workflow should run.
For example, the
push
…
### Using activity types and filters with multiple events
If you specify activity types or filters for an event and your workflow triggers on multiple events, you must configure each event separately. You must append a colon (
:
) to all events, including events without configuration.
…
## on.<event_name>.types
Use
on.<event_name>.types
to define the type of activity that will trigger a workflow run. Most GitHub events are triggered by more than one type of activity. For example, the
…
## on.<pull_request|pull_request_target>.<branches|branches-ignore>
When using the
pull_request
and
…
### Example: Including branches
The patterns defined in
branches
are evaluated against the Git ref's name. For example, the following workflow would run whenever there is a
…
# Sequence of patterns matched against refs/heads

    
branches:
…
### Example: Excluding branches
When a pattern matches the
branches-ignore
pattern, the workflow will not run. The patterns defined in
…
# Sequence of patterns matched against refs/heads

    
branches-ignore:
…
### Example: Including and excluding branches
You cannot use
branches
and
…
## on.push.<branches|tags|branches-ignore|tags-ignore>
When using the
push
event, you can configure a workflow to run on specific branches or tags.
…
### Example: Including branches and tags
The patterns defined in
branches
and
…
# Sequence of patterns matched against refs/heads

    
branches:
…
# Sequence of patterns matched against refs/tags

    
tags:
…
### Example: Excluding branches and tags
When a pattern matches the
branches-ignore
or
…
# Sequence of patterns matched against refs/heads

    
branches-ignore:
…
# Sequence of patterns matched against refs/tags

    
tags-ignore:
…
### Example: Including and excluding branches and tags
You can't use
branches
and
…
## on.<push|pull_request|pull_request_target>.<paths|paths-ignore>
When using the
push
and
…
### Example: Including paths
If at least one path matches a pattern in the
paths
filter, the workflow runs. For example, the following workflow would run anytime you push a JavaScript file (
…
### Example: Excluding paths
When all the path names match patterns in
paths-ignore
, the workflow will not run. If any path names do not match patterns in
…
### Example: Including and excluding paths
You cannot use
paths
and
…
### Git diff comparisons
The filter determines if a workflow should run by evaluating the changed files and running them against the
paths-ignore
or
…
## on.schedule
You can use
on.schedule
to define a time schedule for your workflows.
…
## on.workflow_call
Use
on.workflow_call
to define the inputs and outputs for a reusable workflow. You can also map the secrets that are available to the called workflow. For more information on reusable workflows, see
…
## on.workflow_call.inputs
When using the
workflow_call
keyword, you can optionally specify inputs that are passed to the called workflow from the caller workflow. For more information about the
…
### Example of
on.workflow_call.inputs
```
on:
…
## on.workflow_call.inputs.<input_id>.type
Required if input is defined for the
on.workflow_call
keyword. The value of this parameter is a string specifying the data type of the input. This must be one of:
…
## on.workflow_call.outputs
A map of outputs for a called workflow. Called workflow outputs are available to all downstream jobs in the caller workflow. Each output has an identifier, an optional
description,
and a
…
### Example of
on.workflow_call.outputs
```
on:
…
# Map the workflow outputs to job outputs

    
outputs:
…
## on.workflow_call.secrets
A map of the secrets that can be used in the called workflow.
Within the called workflow, you can use the
secrets
…
### Example of
on.workflow_call.secrets
```
on:
…
# passing the secret to an action

      
-
…
# passing the secret to a nested reusable workflow

  
pass-secret-to-workflow:
…
## on.workflow_call.secrets.<secret_id>
A string identifier to associate with the secret.
## on.workflow_call.secrets.<secret_id>.required
A boolean specifying whether the secret must be supplied.
## on.workflow_run.<branches|branches-ignore>
When using the
workflow_run
event, you can specify what branches the triggering workflow must run on in order to trigger your workflow.
…
## on.workflow_dispatch
When using the
workflow_dispatch
event, you can optionally specify inputs that are passed to the workflow.
…
## on.workflow_dispatch.inputs
The triggered workflow receives the inputs in the
inputs
context. For more information, see
…
### Example of
on.workflow_dispatch.inputs
```
on:
…
## on.workflow_dispatch.inputs.<input_id>.required
A boolean specifying whether the input must be supplied.
## on.workflow_dispatch.inputs.<input_id>.type
The value of this parameter is a string specifying the data type of the input. This must be one of:
boolean
,
…
## permissions
You can use
permissions
to modify the default permissions granted to the
…
### Defining access for the
GITHUB_TOKEN
scopes
You can define the access that the
…
#### Changing the permissions in a forked repository
You can use the
permissions
key to add and remove read permissions for forked repositories, but typically you can't grant write access. The exception to this behavior is where an admin user has selected the
…
## How permissions are calculated for a workflow job
The permissions for the
GITHUB_TOKEN
are initially set to the default setting for the enterprise, organization, or repository. If the default is set to the restricted permissions at any of these levels then this will apply to the relevant repositories. For example, if you choose the restricted default at the organization level then all repositories in that organization will use the restricted permissions as the default. The permissions are then adjusted based on any configuration within the workflow file, first at the workflow level and then at the job level. Finally, if the workflow was triggered by a pull request event other than
…
### Setting the
GITHUB_TOKEN
permissions for all jobs in a workflow
You can specify
…
#### Example: Setting the
GITHUB_TOKEN
permissions for an entire workflow
This example shows permissions being set for the
…
### Using the
permissions
key for forked repositories
You can use the
…
### Permissions for workflow runs triggered by Dependabot
Workflow runs triggered by Dependabot pull requests run as if they are from a forked repository, and therefore use a read-only
GITHUB_TOKEN
. These workflow runs cannot access any secrets. For information about strategies to keep these workflows secure, see
…
## env
A
map
of variables that are available to the steps of all jobs in the workflow. You can also set variables that are only available to the steps of a single job or to a single step. For more information, see
…
### Example of
env
```
env:
…
## defaults
Use
defaults
to create a
…
## defaults.run
You can use
defaults.run
to provide default
…
### Example: Set the default shell and working directory
```
defaults:

…
## defaults.run.shell
Use
shell
to define the
…
## defaults.run.working-directory
Use
working-directory
to define the working directory for the
…
## concurrency
Use
concurrency
to ensure that only a single job or workflow using the same concurrency group will run at a time. A concurrency group can be any string or expression. The expression can only use
…
### Example: Using concurrency and the default behavior
The default behavior of GitHub Actions is to allow multiple jobs or workflow runs to run concurrently. The
concurrency
keyword allows you to control the concurrency of workflow runs.
…
### Example: Concurrency groups
Concurrency groups provide a way to manage and limit the execution of workflow runs or jobs that share the same concurrency key.
The
concurrency
…
### Example: Queueing multiple pending runs
By default, only one job or workflow run can be
pending
in a concurrency group at a time. To allow multiple runs to queue instead of being canceled, set
…
### Example: Using concurrency to cancel any in-progress job or run
To use concurrency to cancel any in-progress job or run in GitHub Actions, you can use the
concurrency
key with the
…
### Example: Using a fallback value
If you build the group name with a property that is only defined for specific events, you can use a fallback value. For example,
github.head_ref
is only defined on
…
### Example: Only cancel in-progress jobs or runs for the current workflow
If you have multiple workflows in the same repository, concurrency group names must be unique across workflows to avoid canceling in-progress jobs or runs from other workflows. Otherwise, any previously in-progress or pending job will be canceled, regardless of the workflow.
To only cancel in-progress runs of the same workflow, you can use the
github.workflow
…
### Example: Only cancel in-progress jobs on specific branches
If you would like to cancel in-progress jobs on certain branches but not on others, you can use conditional expressions with
cancel-in-progress
. For example, you can do this if you would like to cancel in-progress jobs on development branches but not on release branches.
…
## jobs
A workflow run is made up of one or more
jobs
, which run in parallel by default. To run jobs sequentially, you can define dependencies on other jobs using the
…
## jobs.<job_id>
Use
jobs.<job_id>
to give your job a unique identifier. The key
…
### Example: Creating jobs
In this example, two jobs have been created, and their
job_id
values are
…
## jobs.<job_id>.name
Use
jobs.<job_id>.name
to set a name for the job, which is displayed in the GitHub UI.
## jobs.<job_id>.permissions
For a specific job, you can use
jobs.<job_id>.permissions
to modify the default permissions granted to the
…
### Defining access for the
GITHUB_TOKEN
scopes
You can define the access that the
…
#### Changing the permissions in a forked repository
You can use the
permissions
key to add and remove read permissions for forked repositories, but typically you can't grant write access. The exception to this behavior is where an admin user has selected the
…
#### Example: Setting the
GITHUB_TOKEN
permissions for one job in a workflow
This example shows permissions being set for the
…
## jobs.<job_id>.needs
Use
jobs.<job_id>.needs
to identify any jobs that must complete successfully before this job will run. It can be a string or array of strings. If a job fails or is skipped, all jobs that need it are skipped unless the jobs use a conditional expression that causes the job to continue. If a run contains a series of jobs that need each other, a failure or skip applies to all jobs in the dependency chain from the point of failure or skip onwards. If you would like a job to run even if a job it is dependent on did not succeed, use the
…
### Example: Requiring successful dependent jobs
```
jobs:

…
### Example: Not requiring successful dependent jobs
```
jobs:

…
## jobs.<job_id>.if
You can use the
jobs.<job_id>.if
conditional to prevent a job from running unless a condition is met. You can use any supported context and expression to create a conditional. For more information on which contexts are supported in this key, see
…
### Example: Only run job for specific repository
This example uses
if
to control when the
…
## jobs.<job_id>.runs-on
Use
jobs.<job_id>.runs-on
to define the type of machine to run the job on.
…
### Choosing GitHub-hosted runners
If you use a GitHub-hosted runner, each job runs in a fresh instance of a runner image specified by
runs-on
.
…
### Standard GitHub-hosted runners for public repositories
For public repositories, jobs using the workflow labels shown in the table below will run with the associated specifications. With the exception of single-CPU runners, each GitHub-hosted runner is a new virtual machine (VM) hosted by GitHub. Single-CPU runners are hosted in a container on a shared VM—see
GitHub-hosted runners reference
. Use of the standard GitHub-hosted runners is free and unlimited on public repositories.
…
### Standard GitHub-hosted runners for  private repositories
For  private repositories, jobs using the workflow labels shown in the table below will run on virtual machines with the associated specifications. These runners use your GitHub account's allotment of free minutes, and are then charged at the per minute rates. See
Actions runner pricing
.
…
#### Example: Specifying an operating system
```
runs-on:
 
…
### Choosing self-hosted runners
To specify a self-hosted runner for your job, configure
runs-on
in your workflow file with self-hosted runner labels.
…
#### Example: Using labels for runner selection
```
runs-on:
 [
…
### Choosing runners in a group
You can use
runs-on
to target runner groups, so that the job will execute on any runner that is a member of that group. For more granular control, you can also combine runner groups with labels.
…
#### Example: Using groups to control where jobs are run
In this example, runners have been added to a group called
build-runners
. The
…
#### Example: Combining groups and labels
When you combine groups and labels, the runner must meet both requirements to be eligible to run the job.
In this example, the
runs-on
…
## jobs.<job_id>.snapshot
You can use
jobs.<job_id>.snapshot
to generate a custom image.
…
## jobs.<job_id>.environment
Use
jobs.<job_id>.environment
to define the environment that the job references.
…
### Example: Using a single environment name
```
environment:
 
…
### Example: Using environment name and URL
```
environment:

…
### Example: Using output as URL
```
environment:

…
### Example: Using an expression as environment name
```
environment:

…
### Example: Using an environment without creating a deployment
Set
deployment
to
…
## jobs.<job_id>.concurrency
You can use
jobs.<job_id>.concurrency
to ensure that only a single job or workflow using the same concurrency group will run at a time. A concurrency group can be any string or expression. Allowed expression contexts:
…
### Example: Using concurrency and the default behavior
The default behavior of GitHub Actions is to allow multiple jobs or workflow runs to run concurrently. The
concurrency
keyword allows you to control the concurrency of workflow runs.
…
### Example: Concurrency groups
Concurrency groups provide a way to manage and limit the execution of workflow runs or jobs that share the same concurrency key.
The
concurrency
…
### Example: Queueing multiple pending runs
By default, only one job or workflow run can be
pending
in a concurrency group at a time. To allow multiple runs to queue instead of being canceled, set
…
### Example: Using concurrency to cancel any in-progress job or run
To use concurrency to cancel any in-progress job or run in GitHub Actions, you can use the
concurrency
key with the
…
### Example: Using a fallback value
If you build the group name with a property that is only defined for specific events, you can use a fallback value. For example,
github.head_ref
is only defined on
…
### Example: Only cancel in-progress jobs or runs for the current workflow
If you have multiple workflows in the same repository, concurrency group names must be unique across workflows to avoid canceling in-progress jobs or runs from other workflows. Otherwise, any previously in-progress or pending job will be canceled, regardless of the workflow.
To only cancel in-progress runs of the same workflow, you can use the
github.workflow
…
### Example: Only cancel in-progress jobs on specific branches
If you would like to cancel in-progress jobs on certain branches but not on others, you can use conditional expressions with
cancel-in-progress
. For example, you can do this if you would like to cancel in-progress jobs on development branches but not on release branches.
…
## jobs.<job_id>.outputs
You can use
jobs.<job_id>.outputs
to create a
…
### Example: Defining outputs for a job
```
jobs:

…
# Map a step output to a job output

    
outputs:
…
### Using Job Outputs in a Matrix Job
Matrices can be used to generate multiple outputs of different names. When using a matrix, job outputs will be combined from all jobs inside the matrix.
```
jobs:
…
# Will show

      
# {

      
#   "output_1": "1",

      
#   "output_2": "2",

      
#   "output_3": "3"

      
# }

      
-
…
## jobs.<job_id>.env
A
map
of variables that are available to all steps in the job. You can set variables for the entire workflow or an individual step. For more information, see
…
### Example of
jobs.<job_id>.env
```
jobs:
…
## jobs.<job_id>.defaults
Use
jobs.<job_id>.defaults
to create a
…
## jobs.<job_id>.defaults.run
Use
jobs.<job_id>.defaults.run
to provide default
…
## jobs.<job_id>.defaults.run.shell
Use
shell
to define the
…
## jobs.<job_id>.defaults.run.working-directory
Use
working-directory
to define the working directory for the
…
### Example: Setting default
run
step options for a job
```
…
## jobs.<job_id>.steps
A job contains a sequence of tasks called
steps
. Steps can run commands, run setup tasks, or run an action in your repository, a public repository, or an action published in a Docker registry. Not all steps run actions, but all actions run as a step. Each step runs in its own process in the runner environment and has access to the workspace and filesystem. Because steps run in their own process, changes to environment variables are not preserved between steps. GitHub provides built-in steps to set up and complete a job.
…
### Example of
jobs.<job_id>.steps
```
name:
…
## jobs.<job_id>.steps[*].id
A unique identifier for the step. You can use the
id
to reference the step in contexts. For more information, see
…
## jobs.<job_id>.steps[*].if
You can use the
if
conditional to prevent a step from running unless a condition is met. You can use any supported context and expression to create a conditional. For more information on which contexts are supported in this key, see
…
### Example: Using contexts
This step only runs when the event type is a
pull_request
and the event action is
…
### Example: Using status check functions
The
my backup step
on

*(compressed/truncated)*

### Supported Formats & Variants

Refer to the upstream page for version-specific variants.

# Citations

[1] [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
