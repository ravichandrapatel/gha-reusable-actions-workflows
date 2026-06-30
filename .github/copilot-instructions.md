# Copilot Instructions for Ops-Knowledge

To ensure high performance and token efficiency, GitHub Copilot must follow these strict protocols when interacting with this repository.

## Token-Efficient Navigation

1. **Direct File Access Only:**
   - ALWAYS use `#file` or explicit paths when referencing documentation.
   - Start your navigation from the master `rulebooks/_router.md` file.
   - DO NOT perform broad workspace semantic searches. This is banned to keep token costs at a minimum and ensure precision.

2. **Router-First Protocol:**
   - If you are unsure where a standard is located, consult the master `rulebooks/_router.md` or the sub-router in the relevant domain folder (e.g., `rulebooks/terraform/_router.md`).

## Context Collision Protocol

If there is a conflict between Internal Standards and Official Reference files:
1. **Internal Standards ALWAYS Win:** Ignore the Official Reference docs if an Internal Standard exists for the same topic.
2. **Hierarchy of Truth:**
   - `rulebooks/internal-standards/` (The Law) > `rulebooks/[domain]/` (The Dictionary).

## Response Requirements

- When providing infrastructure advice, cite the specific file path used as the source of truth.
- If no internal standard is found, explicitly state that you are falling back to the official reference.
