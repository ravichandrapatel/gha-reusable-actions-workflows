---
type: Playbook
title: Author GHA Composite Action
description: Scaffold and validate a new composite action under actions/{category}/{name}/.
tags: [github-actions, playbook, authoring]
timestamp: 2026-07-14T17:40:00Z
status: active
---

# Trigger

You need a new composite GitHub Action in the monorepo.

# Preconditions

- Layout standard understood: [GHA component layout](/standards/gha-component-layout.md).
- Local SPVS tooling available (or use Release Manager later).

# Steps

1. Create `actions/{category}/{name}/` with `action.yml` and `readme.md`.
2. When an agent authors the action, assemble a **Prompt Pack** with `python3 _okf_knowledge/kernel/okf.py card` on layout + SPVS (+ pins) — see [OKF Prompt Injection](/standards/okf-prompt-injection.md). **MUST NOT** paste full standards.
3. Follow SPVS shell/env patterns: `set -euo pipefail`, map inputs via `env`, pin third-party `uses:` to SHA.
4. Python helpers **MUST** use `argparse` and be runnable standalone — [Python CLI Args](/standards/python-cli-args.md). The composite passes mapped env values as CLI flags to `python3 -u`.
5. Keep `readme.md` short (inputs/outputs + one usage example).
6. Run Conftest composite scan:

```bash
conftest test --parser yaml -n composite \
  -p policies/conftest/github_actions/composite \
  -p policies/conftest/github_actions/lib \
  actions/{category}/{name}/action.yml
```

7. If Conftest fails on `CKV2_SPVS_5`, remediate with a **pin cache** (tag→SHA) rather than asking the agent to discover SHAs from scratch.
8. Run Bandit/Shellcheck on helpers if present.
9. Open PR with a ticket-prefixed conventional subject.

# Verification

- [ ] Directory matches layout standard
- [ ] Conftest composite scan passes
- [ ] Python helpers use argparse and run standalone
- [ ] `readme.md` documents inputs/outputs
- [ ] Agent prompt used a minimal card (not full SPVS dump)

## Prompt Card

```text
New composite action: actions/{category}/{name}/ with action.yml + short readme.md.
Shell: set -euo pipefail; map inputs via env (no ${{ inputs.* }} in run);
python3 -u with argparse flags (standalone runnable); pin uses: to 40-char SHA.
Gate: conftest test --parser yaml -n composite -p policies/conftest/github_actions/{composite,lib}.
PR subject: ticket-prefixed conventional commit.
```

# Related

- Standard: [OKF Prompt Injection](/standards/okf-prompt-injection.md)
- Standard: [GHA SPVS YAML](/standards/gha-spvs-yaml.md), [GHA component layout](/standards/gha-component-layout.md), [Python CLI Args](/standards/python-cli-args.md)
- Concept: [GitHub Actions](/vault/concepts/github-actions.md)
- Concept: [Notification Email composite](/vault/concepts/notification-email.md) (example house composite)
- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
