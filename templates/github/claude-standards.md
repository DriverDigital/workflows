# House standards

Shared across every Driver repo. A repo copies this file to `.github/claude-standards.md` once and
imports it from its `CLAUDE.md` with `@.github/claude-standards.md`; the fleet wave keeps the copy
current. Edit it in `DriverDigital/workflows` (`templates/github/claude-standards.md`), never in place.

- **Commit messages** — Natural language, not strict conventional-commit formatting. Succinct: what
  changed, plus any rationale a senior developer would need later. No history, narratives, or
  who-decided-what.
- **Code comments** — Code should be self-describing whenever possible. Comments are written as one
  senior engineer to another, only to clarify complex or non-obvious code, in 2–3 lines at most. Never
  make junior-level comments (e.g. saying what a for loop does), and never put requirements, decisions,
  or history in a comment. In a theme repo, each Liquid file opens with a short `{% comment %}` saying
  what it is, where it's used, and any setup it needs.
- **To-dos** — One-off to-dos are GitHub issues labelled `todo` on the repo they belong to. The
  driver-skills plugin lists a repo's open ones at session start, and its todo-capture skill files new
  ones, including cross-repo handoffs with a `from:` line. Close the issue when done. `CLAUDE.local.md`
  is not used in Driver repos.
- **`ponytail:` comments** — One line naming a ceiling someone could realistically hit (e.g. a
  hardcoded limit that mirrors a setting elsewhere, or an unpaginated cap). Other simplifications
  need no comment.
