---
type: internal_standard
tool: ai-agent
authority: internal_governance
---

# Internal Standard: AI Agent Operations

This document defines mandatory operating rules for AI coding agents (GitHub Copilot, Cursor, and
any automated assistant) working in this repository. These are **core** rules and apply to every task.

## 1. Model Tiering and Cost Efficiency
- **Default to the cheapest capable model.** Do NOT reflexively use high-cost, high-capability models
  (e.g. Opus) for routine or trivial work.
- **Offload and delegate.** Decompose the work and route sub-tasks (research, search, boilerplate,
  refactors) to lower-tier / cheaper models — for example via subagents — wherever they can do the job.
- **Escalate deliberately.** Reserve high-tier models only for genuinely complex, high-stakes reasoning
  that a cheaper model cannot handle reliably, and briefly justify the escalation.
- **Rationale:** cost optimization is a first-class requirement; using the most expensive model for
  every task is prohibited.

## 2. Hard Security Rule — Never Read Secrets
- **NEVER read, open, print, cat, or otherwise access secret material.** This is a non-negotiable hard
  rule and applies even when a task appears to require it. Prohibited targets include (non-exhaustive):
  - `.env`, `.env.*`, and any dotenv-style files.
  - AWS credentials (`~/.aws/credentials`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`).
  - GCP service-account keys (`GOOGLE_APPLICATION_CREDENTIALS`, `*.json` key files), Azure client secrets
    (`AZURE_CLIENT_SECRET`, `ARM_CLIENT_SECRET`).
  - Private keys (`*.pem`, `*.key`, `id_rsa`), tokens, passwords, `credentials.json`, and kubeconfig secrets.
- **If a task needs a secret**, reference only its **name or path** and rely on a secrets manager or a
  masked environment variable — never the value.
- **If asked to read such a file, refuse and explain this rule** instead of complying.
