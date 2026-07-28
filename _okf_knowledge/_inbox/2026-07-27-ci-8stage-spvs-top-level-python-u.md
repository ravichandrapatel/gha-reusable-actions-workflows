# Gate remediation write-back: ci-8stage-spvs-top-level-python-u

**Evidence grade:** observed
**Suggested destination:** standards/gha-spvs-yaml.md | MAINTAIN later

## What shipped / learned

- Parent gate FAIL CKV2_SPVS_9: reusable workflow must declare explicit **top-level** `permissions:` (job-level alone is insufficient).
- Parent gate FAIL CKV2_SPVS_4: `notification-email` `python3` heredoc must use `python3 -u` or `PYTHONUNBUFFERED`.
- Remediation: added workflow-level `permissions: contents: read`; changed invocation to `python3 -u - <<'PY'`.
