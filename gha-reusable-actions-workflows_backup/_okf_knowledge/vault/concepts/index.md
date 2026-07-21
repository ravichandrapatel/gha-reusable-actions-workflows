# Vault: Concepts

Core definitions and architectural patterns live here.
Every file is `type: Concept`.

| Title | Description |
| :--- | :--- |
| [Aegis Capability Discovery](aegis-capability-discovery.md) | Probe environment caps before enabling Brain/OpenSpec/Git; Runtime States derive exit codes. |
| [Component Tagging](component-tagging.md) | safe_name derivation and versioned vs stable tag conventions for GHA components. |
| [Extending Aegis](extending-aegis.md) | How to grow this empty framework with your own standards and vault knowledge. |
| [GitHub Actions](github-actions.md) | Domain routing for composite actions, reusable workflows, Release Manager, and SPVS Conftest. |
| [GHA CI pipeline recipe](gha-ci-pipeline-recipe.md) | Multi-job CI MUST checkout + real artifacts + house OWASP action; no stub staging as design. |
| [GHA YAML Anchors](gha-yaml-anchors.md) | Reuse env, steps, or jobs inside one GitHub Actions workflow with YAML anchors (&) and aliases (*) — no merge keys. |
| [Release Manager Modes](release-manager-modes.md) | release, promote, and rollback semantics for the gha-reusable-actions-workflows Release Manager. |
| [SemVer from Commits](semver-from-commits.md) | How ticket conventional commits map to SemVer bumps for component tags. |
| [SPVS Lifecycle](spvs-lifecycle.md) | OWASP SPVS stages mapped onto this monorepo, plus Dependency-Check runner constraints. |
