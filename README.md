# local-review.nvim

Local inline review comments for AI-agent coding workflows.

This plugin lets you leave review comments at the line you are reading in
Neovim, without modifying source files and without opening a GitHub or GitLab
review. When you are done, it generates a markdown prompt that you can paste
into Codex or another coding agent.

## Status

Experimental MVP.

The current version stores comments only in memory while Neovim is open.

## Requirements

- Neovim 0.9 or newer
- Git is optional, but recommended for project-relative file paths
- Clipboard support if you want `:LocalReviewDone` to copy to the system
  clipboard

## Installation

During local development with lazy.nvim:

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
- clears the in-memory session and virtual text markers

Abort the review:

```vim
:LocalReviewAbort
```

This clears the in-memory session and virtual text markers without generating a
prompt.

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

## Current Limitations

- Comments are not persisted across Neovim restarts.
- Comments cannot be edited or deleted individually yet.
- There is no review list UI yet.
- The plugin does not integrate with diffview.nvim, fugitive, or gitsigns yet.
- The generated prompt template is not configurable yet.

## Roadmap

Possible next steps:

- `:LocalReviewList`
- `:LocalReviewEdit R1`
- `:LocalReviewDelete R1`
- persisted `.local-review/session.json`
- configurable prompt template
- optional signs in the sign column
