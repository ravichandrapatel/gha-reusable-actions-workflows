# Maven

Composite action that runs `mvn` with caller-supplied goals and CLI arguments.

## Overview

- Use **`actions/setup-java`** in the workflow for Java.
- Write **`settings.xml`** in the workflow (heredoc + org secrets) when Nexus publish needs credentials; pass `-s <path>` in `args`.
- On self-hosted runners, set `maven-setup: auto` to install Apache Maven when `mvn` / `mvnw` are missing.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `args` | Yes | — | Maven goals and options, e.g. `clean verify -DskipTests` or `deploy -s settings.xml` |
| `maven-setup` | No | `auto` | `auto` installs Apache Maven when missing, `skip` or `require` |
| `maven-version` | No | auto | Override install version; empty reads `pom.xml` `<maven.version>`, else `3.9.9` |
| `working-directory` | No | workspace root | Directory containing `pom.xml` |
| `maven-opts` | No | `""` | Sets `MAVEN_OPTS` for the run |

## Outputs

| Output | Description |
| --- | --- |
| `exit_code` | Maven process exit code |
| `project_version` | `project.version` from `pom.xml` after a successful run |
| `java_home` | `JAVA_HOME` from the runner |
| `maven_version` | Resolved Maven version (PATH or install) |

## Maven version resolution

When a download is needed (`maven-setup: auto`, no `mvnw`, no `mvn` on PATH):

1. `maven-version` input (if set)
2. `pom.xml` → `<maven.version>`
3. House default **`3.9.9`**

If `./mvnw` exists, it is used directly. If `mvn` is on PATH, that binary is used.

```yaml
- uses: actions/setup-java@b6effb05e454b25005698d916606bdc6ffcbf961 # v5.7.0
  with:
    distribution: temurin
    java-version: "21"
    cache: maven

- uses: ./actions/common/maven
  with:
    args: clean verify -DskipTests
    maven-setup: skip
```

### Nexus publish (settings in workflow)

```yaml
- name: Write Maven settings
  env:
    NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
    NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
  run: |
    cat > "${{ runner.temp }}/settings.xml" <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <settings xmlns="http://maven.apache.org/SETTINGS/1.2.0">
      <servers>
        <server>
          <id>nexus</id>
          <username>${NEXUS_USERNAME}</username>
          <password>${NEXUS_PASSWORD}</password>
        </server>
      </servers>
    </settings>
    EOF
    chmod 600 "${{ runner.temp }}/settings.xml"

- uses: ./actions/common/maven
  with:
    args: deploy -DskipTests -s ${{ runner.temp }}/settings.xml
```

## Related

- [`maven-build-pipeline`](../../../workflows/programming/maven-build-pipeline/readme.md)
