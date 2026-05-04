# local-review.nvim

Local inline review comments for AI-agent coding workflows.

This plugin lets you leave review comments at the line you are reading in
Neovim, without modifying source files and without opening a GitHub or GitLab
review. When you are done, it generates a markdown prompt that you can paste
into Codex or another coding agent.

## Why This Exists

AI coding agents are good at making local changes, but reviewing those changes
with localized comments is still awkward. Opening a remote pull request can be
too public or too heavy for experimental work, while writing notes in a separate
file loses the exact code location.

`local-review.nvim` keeps the review loop local:

1. Let an agent modify code.
2. Review the changes in Neovim.
3. Leave inline comments without changing source files.
4. Export a structured prompt.
5. Paste the prompt back into the agent.

## Status

Experimental MVP.

The current version stores comments in memory and writes a session backup to
`.local-review/session.json`. `:LocalReviewStart` restores that session when it
finds one for the current project.

## Requirements

- Neovim 0.10 or newer
- Git is optional, but recommended for project-relative file paths
- Clipboard support if you want `:LocalReviewDone` to copy to the system
  clipboard

## Installation

With lazy.nvim:

```lua
{
  "eltonsst/local-review.nvim",
  config = function()
    require("local_review").setup({
      keymap = "<leader>rc",
    })
  end,
}
```

During local development:

```lua
{
  dir = "~/learning/local-review.nvim",
  name = "local-review.nvim",
  config = function()
    require("local_review").setup({
      keymap = "<leader>rc",
    })
  end,
}
```

The plugin also works without calling `setup()`. In that case, use the commands
directly.

## Quick Demo

```vim
:LocalReviewStart
:LocalReviewComment
```

Write a multiline markdown comment in the floating window, then press `<C-s>`.
The reviewed line shows virtual text like:

```text
review R1
```

Inspect collected comments:

```vim
:LocalReviewList
```

Finish and copy the generated agent prompt:

```vim
:LocalReviewDone
```

## Usage

Start a review session:

```vim
:LocalReviewStart
```

Add a comment at the current cursor line:

```vim
:LocalReviewComment
```

This opens a floating markdown buffer.

- Write your review comment.
- Press `<C-s>` to save it.
- Press `<Esc>` in normal mode to cancel.

Saved comments are shown with virtual text at the reviewed line, such as:

```text
review R1
```

Finish the review:

```vim
:LocalReviewDone
```

This command:

- builds a markdown prompt
- copies it to the `+` clipboard register
- saves a backup to `.local-review/last-review.md`
- removes `.local-review/session.json`
- clears the in-memory session and virtual text markers

Abort the review:

```vim
:LocalReviewAbort
```

This clears the in-memory session and virtual text markers without generating a
prompt. It also removes `.local-review/session.json`.

Check current review state:

```vim
:LocalReviewStatus
```

This shows whether a session is active, how many comments are stored, and the
latest comment location.

List current review comments:

```vim
:LocalReviewList
```

This opens the quickfix list with one item per stored comment. Press Enter on a
quickfix item to jump back to the reviewed line.

Delete a review comment:

```vim
:LocalReviewDelete R1
```

This removes the stored comment and clears its virtual text marker.

Edit a review comment:

```vim
:LocalReviewEdit R1
```

This reopens the floating markdown buffer with the existing comment text. Saving
updates the stored comment while keeping the same review ID and marker.

## Configuration

Default configuration:

```lua
require("local_review").setup({
  context_lines = 5,
  keymap = nil,
})
```

Options:

- `context_lines`: number of lines captured before and after the reviewed line
- `keymap`: optional normal-mode mapping for `:LocalReviewComment`

Example:

```lua
require("local_review").setup({
  context_lines = 3,
  keymap = "<leader>rc",
})
```

## Generated Prompt

The generated prompt contains:

- general instructions for the coding agent
- each review comment
- file path and line number
- target line
- nearby context

Example:

````markdown
You are addressing a local code review.

Instructions:
- Address every review comment below.
- Do not change unrelated code.
- Preserve the existing style.
- Add or update tests where appropriate.
- After making changes, summarize how each comment was addressed.

Review comments:

## R1 - `lua/local_review/init.lua:10`

Reviewer comment:

> This is a test comment.

Target code:

```
comments = {},
```

Nearby context:

```
local state = {
  active = false,
  comments = {},
  buffers = {},
}
```
````

## Session Backup

While a review is active, comments are backed up to:

```text
.local-review/session.json
```

The session backup is updated when comments are added, edited, or deleted. It is
removed by `:LocalReviewDone` and `:LocalReviewAbort`.

If Neovim closes before the review is done, reopen the project and run:

```vim
:LocalReviewStart
```

The plugin restores saved comments from `.local-review/session.json` and
recreates markers for files that still exist locally.

## Manual Verification

For a quick end-to-end check:

1. Run `:LocalReviewStart`.
2. Run `:LocalReviewComment` on any source line.
3. Save a comment with `<C-s>`.
4. Confirm virtual text appears on the reviewed line.
5. Run `:LocalReviewList` and jump through the quickfix entry.
6. Run `:LocalReviewEdit R1` and update the text.
7. Run `:LocalReviewDelete R1` and confirm the marker disappears.
8. Add another comment and run `:LocalReviewDone`.
9. Confirm the prompt is copied and `.local-review/last-review.md` exists.

## Current Limitations

- The generated prompt template is not configurable yet.
- There are no integrations with diffview.nvim, fugitive, or gitsigns yet.

## License

MIT
