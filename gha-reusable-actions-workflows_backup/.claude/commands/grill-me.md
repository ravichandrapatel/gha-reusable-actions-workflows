---
name: "Grill Me"
description: Relentlessly interview about a plan/design until shared understanding
allowed-tools: Bash(python3 *)
category: Workflow
tags: [workflow, design, interview]
---

Follow the `grill-me` skill (`.claude/skills/grill-me/SKILL.md`).

Interview the user relentlessly about every aspect of the plan until shared understanding. Walk each branch of the decision tree, resolving dependencies one-by-one. For each question, provide your recommended answer. Ask questions **one at a time**. If a question can be answered by exploring the codebase, explore instead.

Ground with OKF when non-trivial:
```bash
python3 _okf_knowledge/kernel/okf.py pack --budget 1200 "<plan keywords>"
```
