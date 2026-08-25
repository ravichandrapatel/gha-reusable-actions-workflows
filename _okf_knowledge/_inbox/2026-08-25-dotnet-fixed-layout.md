# Change close-out write-back: dotnet-fixed-layout

**Evidence grade:** verified
**Suggested destination:** MAINTAIN later

## What shipped / learned
- Dotnet preprocess uses a **fixed** layout only: root `Directory.Build.props` + `global.json`, and `build/Build.csproj`.
- Do **not** select csproj via `APPLICATION_NAME` (still emitted from `project.values`).
- `dotnet_version` comes only from `global.json` `sdk.version` (required).
- Version from csproj `<Version>` else `Directory.Build.props` `<Version>`.
