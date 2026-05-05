# Changelog

## v0.1.3 - 2026-05-05

Review marker preview release.

### Added

- Compact virtual text review markers with comment previews.
- Updated demo screenshot showing the new marker UI.
- Git ignore entry for local `AGENT_CONTEXT.md` handoff files.

### Changed

- Shortened review marker previews to 30 characters.
- Refreshed review markers immediately after editing an existing comment.
- Updated README and vimdoc marker examples.

## v0.1.2 - 2026-05-05

Neovim public polish release.

### Added

- Vim help documentation at `doc/local-review.txt`.
- Healthcheck support with `:checkhealth local_review`.
- README demo screenshot.
- README feature list and clearer dependency fallback notes.
- CI smoke coverage for help tags, help lookup, and healthcheck.

## v0.1.1 - 2026-05-05

Public readiness release.

### Added

- Public-facing README sections for motivation, quick demo, and manual
  verification.
- Stylua formatting configuration.
- GitHub Actions CI for formatting and a headless Neovim smoke test.

### Changed

- Documented Neovim 0.10+ as the supported minimum version.
- Formatted Lua code with Stylua.

## v0.1.0 - 2026-05-05

Initial MVP release.

### Added

- Local review sessions with `:LocalReviewStart`, `:LocalReviewDone`, and
  `:LocalReviewAbort`.
- Multiline floating markdown input for review comments.
- Inline virtual text markers for stored comments.
- Review comment list, edit, and delete commands.
- Markdown prompt generation copied to the system clipboard.
- Backup prompt written to `.local-review/last-review.md`.
- Session backup and restore with `.local-review/session.json`.
- Optional setup with configurable context line count and comment keymap.
