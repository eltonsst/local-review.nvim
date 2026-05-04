# Changelog

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
