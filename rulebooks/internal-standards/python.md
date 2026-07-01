---
type: internal_standard
tool: python
authority: internal_governance
---

# Internal Standard: Python Development

This document defines the mandatory standards for Python development within our organization.

## 1. Environment and Versions
- **Version**: Target Python 3.12 or higher.
- **Dependency Management**: Use `poetry` or `pip` with a `requirements.txt` (including hashes).
- **Future Annotations**: Every module MUST start with `from __future__ import annotations`.

## 2. Code Quality and Style
- **Formatting**: Use `black` for consistent formatting.
- **Linting**: Use `ruff` or `flake8` for linting.
- **Type Hinting**: Mandatory use of type hints. Use `mypy --strict` for verification.
- **Metadata**: Every file must start with the standard metadata header (see Section 6).

## 3. Programming Patterns
- **Data Validation**: Use `pydantic` `BaseModel` for configuration and data schemas with validation.
- **Configuration**: Load environment/config via `pydantic-settings` or `python-dotenv`; never hardcode.
- **Entry Points**: Guard executable scripts with `if __name__ == "__main__":`.
- **Error Handling**: Use custom exception classes (e.g. `class CloudError(Exception)`) and raise with
  context (`raise CloudError(...) from e`). Bare `except:` or `except: pass` is strictly forbidden.

## 4. Security (DevSecOps — non-negotiable)
- **Subprocess Safety**: NEVER use `shell=True` in `subprocess.run()`. Always pass arguments as a list
  (e.g. `subprocess.run(["cmd", "-l", path])`).
- **Forbidden Builtins**: `eval()`, `exec()`, and `os.system()` are prohibited. Use `os.path`, `shutil`,
  or list-based subprocess instead.
- **Shell Strings**: If you must build a shell string, use `shlex.quote()` — but prefer list-based calls.
- **Secrets**: Never hardcode secrets/tokens. Source them from a secrets manager or masked env vars.

## 5. Observability, Tracing, and Logging
- **Structured Logging**: Use `structlog` or `logging.config`; emit JSON in production. Route all
  operational output through a single logger helper that prepends a `PROJECT_PREFIX` (e.g. `[PRBOT]`).
  Do not use raw `print()` for operational logs (machine output like `GITHUB_OUTPUT` is exempt).
- **Numbered Tracing**: Add numbered trace anchors at each major logic gate, e.g. `# [T-01] ...`, with
  errors prefixed `# [ERR-T-01] ...`. Trace/debug statements MUST be **commented out by default**.
- **Numbered Breadcrumbs**: Use greppable `[DBG-NNN]` codes in log messages — `[DBG-000]` for entry,
  `[DBG-001]+` for main flow steps, `[DBG-9xx]` for errors/warnings.

## 6. File and Function Metadata
- **File header** (module docstring/comment) MUST include: `FILE_NAME`, `DESCRIPTION`, `VERSION`
  (SemVer), `EXIT_CODES/SIGNALS`, `AUTHORS`.
- **Function/Class metadata** MUST include (no curly braces `{}`): `INTENT`, `INPUT`, `OUTPUT`,
  `ROLE` (classes: Service/Data/Model), `SIDE_EFFECTS`.

## 7. Testing
- **Framework**: Use `pytest`.
- **Coverage**: Maintain a minimum of 90% code coverage (`pytest-cov`).
- **Mocking**: Use `pytest-mock`/fixtures for external dependencies; `parametrize` for edge cases.
- **Scenarios**: Cover happy path, empty/null inputs, errors, timeouts, and failure modes.
- **Execution**: Run `pytest` (and `bandit` for security) before every commit/PR.
