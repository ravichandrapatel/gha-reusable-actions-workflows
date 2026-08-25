# Maven

Composite action that installs the Apache Maven CLI and runs `mvn` with caller-supplied goals.

## Overview

- Use **`actions/setup-java`** in the workflow for Java.
- Always installs Apache Maven CLI, copies settings, configures git, runs `mvn -s …` in **`GITHUB_WORKSPACE` only**, then cleans up settings (`always()`).
- Use `${env.NAME}` in the template; pass secrets on the step `env:` (`NEXUS_USERNAME`, `NEXUS_PASSWORD`, `GIT_TOKEN`).

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `args` | Yes | — | Maven goals and options, e.g. `clean verify -DskipTests` or `deploy` |
| `maven-version` | No | auto | Apache Maven CLI version; empty reads `pom.xml` `<maven.version>`, else `3.9.9` |
| `maven-opts` | No | `""` | Sets `MAVEN_OPTS` for the run |

## Outputs

| Output | Description |
| --- | --- |
| `exit_code` | Maven process exit code |
| `java_home` | `JAVA_HOME` from the runner |
| `maven_version` | Installed Maven CLI version |
| `settings_path` | `$GITHUB_WORKSPACE/maven/settings.xml` |

## settings.xml template (edit yourself)

File: [`settings.xml.tmpl`](settings.xml.tmpl) → written to `$GITHUB_WORKSPACE/maven/settings.xml`.

| Placeholder | Step env |
| --- | --- |
| `${env.NEXUS_USERNAME}` | `NEXUS_USERNAME` |
| `${env.NEXUS_PASSWORD}` | `NEXUS_PASSWORD` |
| `${env.GIT_TOKEN}` | `GIT_TOKEN` (jgit / scm tag push) |

## Example

```yaml
- uses: ./actions/common/maven
  env:
    NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
    NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
    GIT_TOKEN: ${{ secrets.GIT_TOKEN || github.token }}
  with:
    args: deploy -DskipTests
```

## Related

- [`maven-build-pipeline`](../../../workflows/programming/maven-build-pipeline/readme.md)
