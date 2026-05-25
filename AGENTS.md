# Repository Instructions

For new projects, default to the shared workspace root unless another location
is specified. Do not create new project folders directly under a user's
documents directory.

## Project Memory System

This project maintains institutional knowledge in `docs/project_notes/` for
consistency across implementation sessions.

### Memory Files

- `bugs.md` - Bug log with dates, solutions, and prevention notes.
- `decisions.md` - Architectural Decision Records with context and trade-offs.
- `key_facts.md` - Non-sensitive project configuration and important facts.
- `issues.md` - Work log for implementation progress.

### Memory-Aware Protocols

Before proposing architectural changes:

- Check `docs/project_notes/decisions.md` for existing decisions.
- Verify the proposed approach does not conflict with past choices.
- If it does conflict, acknowledge the existing decision and explain why a
  change is warranted.

When encountering errors or bugs:

- Search `docs/project_notes/bugs.md` for similar issues.
- Apply known solutions if found.
- Document new bugs and solutions when resolved.

When looking up project configuration:

- Check `docs/project_notes/key_facts.md` for architecture facts, public-safe
  constants, and operational conventions.
- Prefer documented facts over assumptions.

When completing implementation work:

- Log completed work in `docs/project_notes/issues.md`.
- Include the date, status, brief description, and relevant GitHub URL when
  available.

### Style Guidelines

- Prefer bullet lists over tables for easy editing.
- Keep entries concise.
- Always include dates for temporal context.
- Do not store secrets, credentials, tokens, private keys, or sensitive values
  in project memory files.
