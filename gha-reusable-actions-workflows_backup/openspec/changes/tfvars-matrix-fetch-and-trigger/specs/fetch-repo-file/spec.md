## ADDED Requirements

### Requirement: Contents API fetch action

The repository MUST provide a composite action at `actions/common/fetch-repo-file` that downloads a file via the GitHub Contents API using an authentication token, writes it to a caller-specified path, and MUST NOT use `raw.githubusercontent.com`.

#### Scenario: Successful fetch writes file

- **WHEN** a workflow invokes the action with a readable `repository`, `path`, `ref`, and valid token
- **THEN** the file contents are written to the configured destination path on the runner
- **AND** the action exits successfully

#### Scenario: Transient failure retries

- **WHEN** the Contents API returns a transient error (including intermittent 404/5xx)
- **THEN** the action retries with backoff up to the configured attempt limit before failing

### Requirement: Build-preprocess integration recipe

The action `readme.md` MUST include a copy-paste recipe showing how an external build-preprocess action or workflow step can call `fetch-repo-file` to load `matrices/workspaces.json` from this monorepo (or configurable owner/repo) without raw CDN URLs.

#### Scenario: Recipe documents uses block

- **WHEN** a developer reads `actions/common/fetch-repo-file/readme.md`
- **THEN** they find an example `uses:` (or equivalent step) suitable to paste into build-preprocess
- **AND** the example sets repository/path/ref for the shared matrix JSON
