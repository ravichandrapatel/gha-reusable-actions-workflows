# Change close-out write-back: read-maven-pom-is-multi-module

**Evidence grade:** verified (unittest after change; Conftest composite)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- `is_multi_module` is `true` only when `<modules>` has at least one non-empty `<module>`. `packaging=pom` alone (BOM / parent without modules) is `false`.
