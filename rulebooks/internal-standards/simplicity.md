---
type: internal_standard
tool: simplicity
authority: internal_governance
---

# Internal Standard: Simplicity & Anti-Over-Engineering

The mandatory posture for all code work: **the laziest solution that actually works** — simplest,
shortest, most minimal. Lazy means efficient, not careless. The best code is code never written.
Default posture is **full** (the ladder below enforced). Synthesized from the `ponytail` skill set
([DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail/tree/main/skills)).

## 1. Intent
- Prevent over-engineering: speculative abstractions, reinvented stdlib, needless dependencies, dead
  flexibility, boilerplate "for later".
- Make the **shortest correct diff** the default outcome — but only after the problem is understood.

## 2. Ranked Principles (highest rank wins on conflict)
| Rank | Principle | Rule |
| :--- | :--- | :--- |
| **P1** | Understand first | Never shorten comprehension. Read the task and every file the change touches; trace the real flow end-to-end **before** simplifying. A tiny diff in the wrong place is a second bug. |
| **P2** | Guardrails are absolute | NEVER simplify away input validation at trust boundaries, error handling that prevents data loss, security, accessibility basics, or anything explicitly requested. |
| **P3** | Root cause, not symptom | Fix in the shared function where all callers route (grep every caller first). One guard in the shared path beats a guard per caller. |
| **P4** | Climb the ladder (§3) | Stop at the first rung that holds. YAGNI → reuse → stdlib → native → installed dep → one line → minimum. |
| **P5** | No unrequested abstractions | No interface with one implementation, no factory for one product, no config for a value that never changes, no layer with one caller. |
| **P6** | Deletion over addition | Fewest files. Shortest working diff. Boring over clever (clever is what someone decodes at 3am). |
| **P7** | Correct over flimsy | Two equal-size options → take the one correct on edge cases. Lazy means less code, not a weaker algorithm. |
| **P8** | Leave one check | Non-trivial logic (branch, loop, parser, money/security path) leaves ONE runnable check (an `assert`-based self-check or one small `test_*`). Trivial one-liners need none — YAGNI applies to tests too. |
| **P9** | Mark deliberate shortcuts | Tag simplifications with a `ponytail:` comment naming the ceiling and upgrade path (e.g. `# ponytail: global lock, per-account locks if throughput matters`). |
| **P10** | Track shortcut debt | Deferrals must be harvestable (§6). A `ponytail:` comment with no named trigger is a rot risk. |
| **P11** | Review only complexity | Over-engineering review/audit (§5) is scoped to complexity; correctness, security, and performance go to a normal review pass. |
| **P12** | Output discipline | Code first, then ≤3 short lines: what was skipped, when to add it. If the explanation is longer than the code, delete the explanation. Requested reports/walkthroughs are exempt. |
| **P13** | Honest metrics | Never invent per-repo savings numbers — the unbuilt version has no baseline. Only counted ledgers (§6) are real figures. |
| **P14** | Physical world needs knobs | Hardware/real-world code keeps its calibration knob; a minimal model can't see drift. |

## 3. The Laziness Ladder
Runs *after* you understand the problem. Stop at the first rung that holds; two rungs work → take the higher.
1. **Does this need to exist at all?** Speculative need → skip it, say so in one line. (YAGNI)
2. **Already in this codebase?** A helper/util/type/pattern that lives here → reuse it. Look before you write.
3. **Stdlib does it?** Use it.
4. **Native platform feature covers it?** e.g. `<input type="date">` over a picker lib, CSS over JS, DB constraint over app code.
5. **Already-installed dependency solves it?** Use it. Never add a new dependency for what a few lines can do.
6. **Can it be one line?** One line.
7. **Only then:** the minimum code that works.

## 4. Intensity Levels
- **lite** — build what's asked, but name the lazier alternative in one line; the author picks.
- **full** *(default)* — the ladder enforced; stdlib and native first; shortest diff and shortest explanation.
- **ultra** — YAGNI extremist; deletion before addition; ship the one-liner and challenge the rest of the requirement in the same response.

## 5. Over-Engineering Review & Audit
Review a **diff** (review) or the **whole tree** (audit). One line per finding, ranked biggest cut first.
Format: `L<line>: <tag> <what>. <replacement>.` (prefix `<file>:` for multi-file).

| Tag | Meaning |
| :--- | :--- |
| `delete:` | Dead code, unused flexibility, speculative feature. Replacement: nothing. |
| `stdlib:` | Hand-rolled thing the standard library ships. Name the function. |
| `native:` | Dependency or code doing what the platform already does. Name the feature. |
| `yagni:` | Abstraction with one implementation, config nobody sets, layer with one caller. |
| `shrink:` | Same logic, fewer lines. Show the shorter form. |

Hunt for: deps the stdlib/platform already ships, single-implementation interfaces, factories with one
product, wrappers that only delegate, files exporting one thing, dead flags/config, hand-rolled stdlib.
End with `net: -<N> lines (-<M> deps) possible.` Nothing to cut → `Lean already. Ship.`
A single smoke test / `assert` self-check (P8) is the minimum, never flag it for deletion.

## 6. Deliberate-Shortcut Debt Ledger
Harvest the `ponytail:` markers so a deferral can't become permanent:
`grep -rnE '(#|//) ?ponytail:' .` (skip `node_modules`, `.git`, build output).
One row per marker: `<file>:<line>, <what was simplified>. ceiling: <limit>. upgrade: <trigger>.`
Any marker with no upgrade path/trigger is tagged `no-trigger` (silent rot). End with
`<N> markers, <M> with no trigger.` Nothing found → `No ponytail: debt. Clean ledger.`
