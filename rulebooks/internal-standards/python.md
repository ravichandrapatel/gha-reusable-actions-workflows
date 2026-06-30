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

## 2. Code Quality and Style
- **Formatting**: Use `black` for consistent formatting.
- **Linting**: Use `ruff` or `flake8` for linting.
- **Type Hinting**: Mandatory use of type hints. Use `mypy --strict` for verification.
- **Metadata**: Every file must start with the standard metadata header (FILE_NAME, DESCRIPTION, VERSION, etc.).

## 3. Programming Patterns
- **Subprocess Safety**: NEVER use `shell=True` in `subprocess.run()`. Always pass arguments as a list.
- **Data Validation**: Use `pydantic` for configuration and data schemas.
- **Error Handling**: Use custom exception classes and avoid bare `except: pass`.
- **Logging**: Use structured logging (e.g., `structlog`). Prepend `[PROJECT-NAME]` to all logs.

## 4. Testing
- **Framework**: Use `pytest`.
- **Coverage**: Maintain a minimum of 90% code coverage.
- **Mocking**: Use `pytest-mock` for external dependencies.
- **Execution**: Run `pytest` before every commit/PR.
