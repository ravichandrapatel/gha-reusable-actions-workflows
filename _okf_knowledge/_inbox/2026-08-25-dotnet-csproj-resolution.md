# Change close-out write-back: dotnet-csproj-resolution

**Evidence grade:** verified
**Suggested destination:** MAINTAIN later (action-local readme already documents; optional vault playbook for build-preprocess)

## What shipped / learned
- Dotnet preprocess must resolve `*.csproj` via `rglob` (skip `bin`/`obj`), not root-only `glob or rglob`.
- `APPLICATION_NAME` must match the csproj **filename stem** (case-insensitive; strip quotes in `project.values`).
- Typical layout: root `Directory.Build.props` (Version) + `global.json` (`sdk.version`) + nested app csproj + optional `build/build.csproj`.
- When name unset and multiple projects exist, prefer `build/build.csproj`.
- Mismatch error must list found stems instead of the generic “set APPLICATION_NAME” ambiguous message when the key is already set but wrong.
