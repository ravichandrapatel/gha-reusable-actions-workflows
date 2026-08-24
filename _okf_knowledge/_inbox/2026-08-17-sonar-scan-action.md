# Change close-out write-back: sonar-scan-action

**Evidence grade:** observed
**Suggested destination:** MAINTAIN later (optional concept under vault/concepts if a reusable-workflow job later wraps this)

## What shipped / learned

- New composite `actions/security/sonar-scan/` wraps pinned `SonarSource/sonarqube-scan-action@22918119ff8e1ca75a623e15c8296b6ea4fbe28f` (v8.2.1 from pin catalog).
- After a successful scan, `ensure_tags.py` GETs `api/components/show` and POSTs `api/project_tags/set` only when a desired tag is missing. Match is case-insensitive; other existing tags are kept.
- Desired tags: `organizations-<org>`, `product-<product>`, `platform-<platform>` with `platform` default `cap`.
- Token needs Sonar **Administer** on the project to set tags. First-scan 404 is retried.
- Conftest composite scan: 14 passed on `action.yml`.
- Quality gate is in the same composite (`SonarSource/sonarqube-quality-gate-action@7a5fffe8e523c40e0c740b6bc2712ab503e52efa`, v1.2.1). Step `continue-on-error` is driven by input `continue_on_error` (default `false`). Tags run after scan and before the gate.
- First step writes `sonar-project.properties` via `generate_properties.py`. For `ng-ui`: sources `apps,package-lock.json`; inclusions replaced with `apps/**,package-lock.json`; dependency-check HTML+JSON under `reports/`; lcov path only if `coverage/lcov.info` exists; PR key/branch/base when all three inputs are set. File contents are printed.
