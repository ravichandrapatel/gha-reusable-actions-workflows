# Maven

Composite action that generates settings, configures git for jgit, and runs `mvn` with caller-supplied goals.

## Overview

- Use **`actions/setup-java`** and install the Apache Maven CLI **in the workflow** before this action (sets `PATH` / `MAVEN_EXECUTABLE`).
- This action copies settings, configures git, runs `mvn -s …` in **`GITHUB_WORKSPACE` only**, then cleans up settings (`always()`).
- Optional `MAVEN_OPTS` via the step `env:` (not an action input).
- Use `${env.NAME}` in the template; pass secrets on the step `env:` (`NEXUS_USERNAME`, `NEXUS_PASSWORD`, `GIT_TOKEN`).

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `MAVEN_ARGS` | Yes | — | Maven goals and options, e.g. `clean verify -DskipTests` or `deploy` |
| `MAVEN_SETTINGS_PATH` | No | `${{ github.workspace }}/maven/settings.xml` | Path written from the template and passed to `mvn -s` |

## settings.xml template (edit yourself)

File: [`settings.xml.tmpl`](settings.xml.tmpl) → written to `MAVEN_SETTINGS_PATH`.

| Placeholder | Step env |
| --- | --- |
| `${env.NEXUS_USERNAME}` | `NEXUS_USERNAME` |
| `${env.NEXUS_PASSWORD}` | `NEXUS_PASSWORD` |
| `${env.GIT_TOKEN}` | `GIT_TOKEN` (jgit / scm tag push) |

## Example

```yaml
- name: Install Maven CLI
  # workflow installs Maven and exports MAVEN_HOME / PATH / MAVEN_EXECUTABLE
  run: # … see maven-build-pipeline

- uses: ./actions/common/maven
  env:
    NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
    NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
    GIT_TOKEN: ${{ secrets.GIT_TOKEN || github.token }}
  with:
    MAVEN_ARGS: deploy -DskipTests
    # MAVEN_SETTINGS_PATH defaults to ${{ github.workspace }}/maven/settings.xml
```

## Related

- [`maven-build-pipeline`](../../../workflows/programming/maven-build-pipeline/readme.md)
