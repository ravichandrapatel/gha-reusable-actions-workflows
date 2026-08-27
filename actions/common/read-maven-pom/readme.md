# Read Maven POM

Composite action that reads a Maven `pom.xml` and emits GAV plus packaging.

## Overview & context

- **Purpose**: Extract `groupId`, `artifactId`, `packaging`, `version`, and `is_multi_module` for later Maven/Nexus steps without grepping XML in the workflow.
- **Scope**: Single POM file. Does not run Maven, resolve `${property}` placeholders, walk a reactor, or inherit `<version>` from parent.
- **Success criteria**: Step exits 0 with all five outputs set. Missing POM, unreadable XML, or missing `groupId` / `artifactId` / project `<version>` exits 1.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/read-maven-pom` |
| **Dependencies** | Python 3; composite installs `requirements.txt` (`defusedxml`) |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `pom_file` | No | `pom.xml` | Path relative to `working_directory`. No `..` segments. |
| `working_directory` | No | `""` | POM root. Empty uses `GITHUB_WORKSPACE`, else the current directory. |

## Outputs

| Output | Description |
| --- | --- |
| `group_id` | Project `<groupId>`, else parent `<groupId>`. |
| `artifact_id` | Project `<artifactId>` (not inherited). |
| `packaging` | Project `<packaging>`, lowercased. Defaults to `jar` when omitted. |
| `version` | Project `<version>` only. Trailing `-SNAPSHOT` is stripped (`1.0.0-SNAPSHOT` → `1.0.0`). Parent `<version>` is never used. |
| `is_multi_module` | `true` when `<modules>` contains at least one non-empty `<module>`; otherwise `false`. Empty `<modules/>` and `packaging=pom` alone are not enough. |

XML namespaces are stripped. `${revision}`-style properties are **not** interpolated.

## Usage

```yaml
- name: Read Maven POM
  id: pom
  uses: ./actions/common/read-maven-pom

- name: Use coordinates
  env:
    GROUP_ID: ${{ steps.pom.outputs.group_id }}
    ARTIFACT_ID: ${{ steps.pom.outputs.artifact_id }}
    PACKAGING: ${{ steps.pom.outputs.packaging }}
    VERSION: ${{ steps.pom.outputs.version }}
    IS_MULTI_MODULE: ${{ steps.pom.outputs.is_multi_module }}
  run: |
    set -euo pipefail
    echo "${GROUP_ID}:${ARTIFACT_ID}:${PACKAGING}:${VERSION} multi=${IS_MULTI_MODULE}"
```

After Release Manager: `ravichandrapatel/gha-reusable-actions-workflows/actions/common/read-maven-pom@read-maven-pom/v1`.

## Manual run

```bash
python3 -u actions/common/read-maven-pom/read_maven_pom.py --pom pom.xml
python3 -u actions/common/read-maven-pom/read_maven_pom.py \
  --working-directory /path/to/app \
  --pom pom.xml
```

Omit `--output` to print `key : value` lines to stdout.

## Release

Tags after Release Manager: `read-maven-pom/v1.0.0` (versioned), `read-maven-pom/v1` (stable, after promote).
