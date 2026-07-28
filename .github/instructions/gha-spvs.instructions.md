---
applyTo: "actions/**,workflows/**,.github/workflows/**,policies/**"
---

# GHA / SPVS authoring

Before inventing composite actions or reusable workflows, pack from package root:

```bash
python3 _okf_knowledge/kernel/okf.py pack --budget 1200 "gha spvs layout pins release"
```

Honor Prompt Cards for:

- SPVS YAML (Conftest MUST pass; no soft-fail)
- Component layout (`actions|workflows/{category}/{name}/` + required readme)
- Commit subjects / SemVer
- Action pin catalog (SHA pins; no floating `@vN` when cards supply pins)

Prefer house `./actions/*` over inventing stubs. Write durable pin/recipe learnings to `_okf_knowledge/_inbox/`.
