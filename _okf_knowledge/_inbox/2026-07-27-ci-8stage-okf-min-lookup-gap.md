# Change close-out write-back: ci-8stage-okf-min-lookup-gap

**Evidence grade:** observed
**Suggested destination:** vault/references/gha-action-pin-catalog.md | MAINTAIN later

## What shipped / learned

- Authored reusable 8-stage CI under `_ab_bench/okf/ci-8stage/` (`workflow.yml`, `README.md`) using Prompt Cards from `okf.py lookup --card` (pipeline recipe, pin catalog, SPVS YAML).
- Extra lookup used once for Nexus/notification pins; catalog still lacked SHA pins for Nexus publish and SMTP/email notification actions.
- Implemented Nexus upload via `curl --upload-file` and email via `python3`+`smtplib` (no `@vN`, not stub local staging) per card rule: missing pin → do not invent Conftest-green stubs; write-back instead.
- Prefer house composites when present: `./actions/security/owasp-dependency-check`, `./actions/common/build-preprocess`.
- Durable catalog gap: add observed SHA pins (or house composites) for Nexus publish and notification-email when verified live.
