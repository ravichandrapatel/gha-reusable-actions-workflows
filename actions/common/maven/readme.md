# Maven

Composite action that runs `mvn` with caller-supplied goals and CLI arguments.

## Overview & context

- **Purpose**: Shared Maven step for house CI — build, test, deploy, or any `mvn` goal string.
- **Scope**: Assumes `mvn` is on PATH. On **self-hosted** runners, pass `java-version` from preprocess / `pom.xml` and the action selects matching `JAVA_HOME`. On **GitHub-hosted** runners, pair with `actions/setup-java` and set `java-setup: skip`.
- **Success criteria**: Exits with Maven’s exit code; writes `exit_code` and optional `project_version` outputs.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/maven` |
| **Dependencies** | bash, Maven on PATH, Java |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `args` | Yes | — | Maven goals and options, e.g. `clean verify -DskipTests` |
| `java-version` | No | `""` | Major Java version from `pom.xml`; selects `JAVA_HOME` on self-hosted runners |
| `java-setup` | No | `auto` | `auto`, `skip`, or `require` |
| `working-directory` | No | workspace root | Directory containing `pom.xml` |
| `maven-executable` | No | `mvn` | Maven binary name or path |
| `settings-file` | No | `""` | Passed as `mvn -s <file>` |
| `maven-opts` | No | `""` | Sets `MAVEN_OPTS` for the run |

## Outputs

| Output | Description |
| --- | --- |
| `exit_code` | Maven process exit code |
| `project_version` | `project.version` from `pom.xml` after a successful run (empty when not readable) |
| `java_home` | `JAVA_HOME` used for the run |

## Usage

### Self-hosted runner (select Java from pom)

```yaml
- uses: ./actions/common/maven
  with:
    args: clean verify -DskipTests
    java-version: "21"
    java-setup: auto
```

### GitHub-hosted runner (setup-java + skip selection)

```yaml
- uses: actions/setup-java@b6effb05e454b25005698d916606bdc6ffcbf961 # v5.7.0
  with:
    distribution: temurin
    java-version: "21"
    cache: maven

- uses: ./actions/common/maven
  with:
    args: clean verify -DskipTests
    java-setup: skip
```

### Build and test

```yaml
- uses: actions/setup-java@b6effb05e454b25005698d916606bdc6ffcbf961 # v5.7.0
  with:
    distribution: temurin
    java-version: "21"
    cache: maven

- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/maven@maven/v1.0.0
  with:
    args: clean verify -DskipTests
```

### Custom settings and working directory

```yaml
- uses: ./actions/common/maven
  with:
    working-directory: services/my-app
    settings-file: .mvn/settings.xml
    args: deploy -Prelease -DskipTests
  env:
    NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
    NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
```

### Snapshot package (jsb-ui / maven apps)

```yaml
- uses: ./actions/common/maven
  id: maven
  with:
    args: clean package -DskipTests

- name: Use version
  run: echo "Built ${{ steps.maven.outputs.project_version }}"
```

## Notes

- **`args` splitting:** Arguments are word-split by the shell (same as `mvn ${{ inputs.args }}` in a workflow step). Quote values in the YAML string when needed, e.g. `-Drevision=1.0.0`.
- **Runner setup:** This action does not install Java or Maven. Callers on `ubuntu-latest` typically pair it with `actions/setup-java` (`cache: maven`).
- **Secrets in settings.xml:** Prefer Maven `settings.xml` server credentials or env vars referenced from the POM; do not pass secrets in `args`.

## Related

- [`build-preprocess`](../build-preprocess/readme.md) — maven metadata and stage gates
- [`ng-ui-build-pipeline`](../../../workflows/programming/ng-ui-build-pipeline/readme.md) — ng-ui pipeline (npm, not Maven)
