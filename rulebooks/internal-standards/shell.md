---
type: internal_standard
tool: shell
authority: internal_governance
---

# Internal Standard: Shell Scripting (Bash/Zsh)

This document defines the mandatory standards for shell scripting within our organization.

## 1. Defensive Coding
- **Strict Mode**: Always start scripts with `set -euo pipefail`.
- **Quoting**: ALWAYS double-quote variables (e.g., `"$VAR"`) to prevent word splitting and globbing.
- **Cleanup**: Use `trap` for cleanup on exit or error.

## 2. Style and Structure
- **Shebang**: Use `#!/usr/bin/env bash` for portability.
- **Naming**: Use `snake_case` for variables and functions.
- **Modularity**: Break complex scripts into functions.
- **Metadata**: Include the standard metadata header at the top of every script.

## 3. Security
- **Inputs**: Validate all external inputs and environment variables.
- **Paths**: Use absolute paths or define a base directory variable.
- **Permissions**: Ensure scripts have the minimum necessary permissions (e.g., `755`).

## 4. Testing and Validation
- **Linting**: Use `shellcheck` on all scripts.
- **Testing**: Use `bats` (Bash Automated Testing System) for complex scripting logic.
- **Traceability**: Use numbered tracing statements (e.g., `[T-01]`) in comments for execution flow.
