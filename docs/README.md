# SPVS Developer Guide

**Monorepo handbook for authoring, testing, and releasing GitHub Actions and reusable workflows**

| | |
| :--- | :--- |
| **Audience** | Platform engineers and component authors |
| **Companion** | [Repository README](../README.md) — architecture, full policy catalog, release lifecycle |
| **Standard** | [OWASP SPVS](https://owasp.org/www-project-spvs) 1.0 |

---

## How to use this guide

Read **Part I → Part IV** in order if you are new to the repository. Use individual chapters as reference once you are familiar with the workflow.

| Part | Chapters | Focus |
| :--- | :--- | :--- |
| **I — Orientation** | [1. Introduction](01-introduction.md) | Repository map, release flow, where policies live |
| **II — Authoring** | [2. Writing components](02-writing-components.md) | Create actions and workflows that pass SPVS |
| **III — Local development** | [3. Git hooks](03-dev-hooks.md) · [4. Testing](04-local-testing.md) | Install hooks, run scans and unit tests |
| **IV — Release** | [5. Release checklist](05-release-checklist.md) | Verify Release Manager in GitHub Actions |

---

## Table of contents

1. **[Introduction](01-introduction.md)** — Start here  
2. **[Writing actions and workflows](02-writing-components.md)**  
3. **[Local git hooks](03-dev-hooks.md)**  
4. **[Local testing](04-local-testing.md)**  
5. **[Release Manager checklist](05-release-checklist.md)**  

---

## Quick paths

| Goal | Go to |
| :--- | :--- |
| First-time setup | [Chapter 3 — Git hooks](03-dev-hooks.md) |
| Add a new action | [Chapter 2 — Writing components](02-writing-components.md) |
| Fix a failed pre-commit scan | [Chapter 4 — Testing](04-local-testing.md#troubleshooting-test-failures) |
| Understand a Checkov policy | [README — Security policies](../README.md#security-policies-spvs--checkov) |
| Ship a release | [Chapter 5 — Release checklist](05-release-checklist.md) |

---

## Document map

```text
docs/                          ← You are here (developer guide)
├── README.md                  ← Title page & table of contents
├── 01-introduction.md
├── 02-writing-components.md
├── 03-dev-hooks.md
├── 04-local-testing.md
└── 05-release-checklist.md

README.md (repo root)          ← Architecture, policies, SemVer, CI prerequisites
policies/
├── github_actions/            ← Checkov policy YAML (CKV2_SPVS_*)
├── scripts/                   ← Hooks, staging, install
└── tests/                     ← Shell unit tests
actions/{category}/{name}/     ← Composite actions
workflows/{category}/{name}/   ← Reusable workflows
```
