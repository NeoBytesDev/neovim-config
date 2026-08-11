# VSCode-style Neovim

A single-file Neovim config that keeps Vim underneath but puts a VSCode keymap on top:
`Ctrl+S` saves, `Ctrl+C`/`Ctrl+X`/`Ctrl+V` use the system clipboard, `Ctrl+Z` undoes in
small chunks, `Shift+arrows` select, and typing over a selection replaces it. Plugins are
managed by [lazy.nvim](https://github.com/folke/lazy.nvim) and bootstrap themselves on
first launch.

Highlights: gruvbox (hard contrast), lualine + bufferline, nvim-tree, telescope,
toggleterm, treesitter (incl. folding), nvim-autopairs, gitsigns, indent-blankline, and
LSP via `nvim-lspconfig` + `mason` with `blink.cmp` for completion.

## Requirements

- Neovim 0.11+ (uses `vim.lsp.enable`, `winfixbuf`, treesitter `main` branch)
- A **Nerd Font** in your terminal (icons in the tree, tabline and statusline)
- `git`, a C compiler and `make` (treesitter parsers, `telescope-fzf-native`)
- `ripgrep` for live grep, `fd` recommended for file finding
- Language servers are installed via `:Mason`; the config enables `pyright`, `clangd` and
  `neocmake`

## Reading the tables

`<leader>` is <kbd>Space</kbd>. The local leader is <kbd>\\</kbd>.

Modes are abbreviated **N** normal, **I** insert, **V** visual, **S** select, **T**
terminal. Most bindings work in all of N/I/V/S so you don't have to think about which
mode you are in.

## Files, buffers and windows

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>S</kbd> | N I V S | Save file (drops back to normal mode) |
| <kbd>Ctrl</kbd>+<kbd>Q</kbd> | N | Close split; if it's the last one, close the buffer |
| <kbd>Space</kbd> <kbd>Q</kbd> | N | Quit Neovim (prompts about unsaved files) |
| <kbd>Space</kbd> <kbd>V</kbd> | N | Vertical split |
| <kbd>Space</kbd> <kbd>H</kbd> | N | Horizontal split |
| <kbd>Ctrl</kbd>+<kbd>P</kbd> | N | Find files (telescope) |
| <kbd>Space</kbd> <kbd>F</kbd> <kbd>G</kbd> | N | Live grep (telescope) |
| <kbd>Ctrl</kbd>+<kbd>B</kbd> | N | Toggle file explorer (nvim-tree) |
| <kbd>Ctrl</kbd>+<kbd>\\</kbd> | N T | Toggle terminal (horizontal split) |

`Ctrl+Q` is deliberately picky: it does nothing in the tree, the terminal or help
windows, so you can't accidentally kill them. When it closes the last code window it
switches to another listed buffer first, so the layout survives.

Terminal windows are pinned to their buffer (`winfixbuf`), so clicking a tab in the
bufferline can't hijack the terminal split.

## Editing

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>C</kbd> | N V S | Copy line / selection to the system clipboard |
| <kbd>Ctrl</kbd>+<kbd>X</kbd> | N V S | Cut line / selection |
| <kbd>Ctrl</kbd>+<kbd>V</kbd> | N I V S | Paste (over the selection in V/S) |
| <kbd>Ctrl</kbd>+<kbd>Z</kbd> | N I V S | Undo |
| <kbd>Ctrl</kbd>+<kbd>Y</kbd> or <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd> | N I V S | Redo |
| <kbd>Tab</kbd> | N V S | Indent line / selection (keeps the selection) |
| <kbd>Shift</kbd>+<kbd>Tab</kbd> | N I V S | Dedent line / selection |
| <kbd>Ctrl</kbd>+<kbd>/</kbd> or <kbd>Alt</kbd>+<kbd>C</kbd> | N I V S | Toggle comment |
| <kbd>Alt</kbd>+<kbd>↑</kbd> / <kbd>Alt</kbd>+<kbd>↓</kbd> | N I V S | Move line / selection up / down (re-indents) |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>↑</kbd> / <kbd>↓</kbd> | N I V S | Same as above (alternative binding) |

Pasting over a selection uses visual `P`, so the clipboard is *not* replaced by whatever
you pasted over — pasting the same text twice in a row works as expected.

Undo is chunked like VSCode's: an undo breakpoint is inserted after <kbd>Space</kbd>,
`.`, `,`, `;` and `:`, so `Ctrl+Z` takes back a word or a clause instead of the entire
insert session. Undo history is persistent across sessions (`undofile`), and there are no
swap files.

## Selection and movement

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>A</kbd> | N I V S | Select all |
| <kbd>Shift</kbd>+arrows / <kbd>Home</kbd> / <kbd>End</kbd> / <kbd>PgUp</kbd> / <kbd>PgDn</kbd> | N I | Start / extend a selection |
| <kbd>Ctrl</kbd>+<kbd>←</kbd> / <kbd>Ctrl</kbd>+<kbd>→</kbd> | N I V | Move one word left / right, never across lines |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>←</kbd> / <kbd>→</kbd> | N I | Select by word |

Word movement is clamped to the current line: past the last word the cursor stops at end
of line, before the first word it stops at column 1 — the same as VSCode, unlike plain
`w`/`b`.

### About Select mode

`keymodel=startsel,stopsel` plus `selectmode=key` means a shifted motion puts you in
**Select** mode rather than Visual mode, so typing a character *replaces* the selection
instead of running a command. That's the VSCode behaviour, but it's the reason the config
maps `x` (visual) and `s` (select) separately everywhere instead of using `v`: in Select
mode the right-hand side of a `v` mapping would be typed as literal text over your
selection. If you want plain Visual mode from a selection, press <kbd>Ctrl</kbd>+<kbd>G</kbd>.

## Folding

Folding is treesitter-based and everything starts unfolded.

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Alt</kbd>+<kbd>F</kbd> | N I V | Toggle fold under the cursor |
| <kbd>Space</kbd> <kbd>Z</kbd> <kbd>R</kbd> | N | Unfold all |
| <kbd>Space</kbd> <kbd>Z</kbd> <kbd>M</kbd> | N | Fold all |

## Completion and LSP

Completion is `blink.cmp` with the `enter` preset, so <kbd>Enter</kbd> accepts the
selected item, <kbd>↑</kbd>/<kbd>↓</kbd> move through the list, <kbd>Tab</kbd>/
<kbd>Shift</kbd>+<kbd>Tab</kbd> jump between snippet placeholders, and
<kbd>Ctrl</kbd>+<kbd>E</kbd> dismisses the menu. Documentation pops up automatically.

Signature help (`lsp_signature.nvim`) shows up while you're inside a call's parentheses
and closes itself when you leave them or move to another line.

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>G</kbd> | I | Toggle the signature window |
| <kbd>Alt</kbd>+<kbd>N</kbd> | I | Cycle to the next overload |

Diagnostics are shown as virtual text at the end of the line, sorted with errors first,
and update live while typing.

## Terminal quirks worth knowing

- <kbd>Ctrl</kbd>+<kbd>/</kbd> is mapped three ways (`<C-_>`, `<C-/>`, `<Alt>+C`)
  because terminals disagree about what that key sends. If the first two don't work in
  yours, <kbd>Alt</kbd>+<kbd>C</kbd> always will.
- <kbd>Ctrl</kbd>+<kbd>3</kbd> is bound to nothing on purpose. Most terminals send it as
  a plain <kbd>Esc</kbd> and it can't be intercepted; in GUI clients and
  kitty-protocol terminals it arrives as a distinct key, and the no-op keeps behaviour
  consistent.
- <kbd>Alt</kbd>+arrow bindings need a terminal that passes Alt through (or a GUI
  client); `Ctrl+Shift+arrows` are provided as the fallback.

## Other defaults

- 4-space indentation, colour column at 100
- `ignorecase` + `smartcase` search
- System clipboard shared with the unnamed register (`unnamedplus`)
- Comment leaders are *not* auto-inserted on new lines
- `netrw` is disabled in favour of nvim-tree
- Treesitter indent is used everywhere except C/C++/Java, where Vim's `cindent` is
  better; in both cases the old C-era rule that snaps `#` to column 0 is removed, so
  typing `#` at the start of an indented Python or shell comment no longer jumps the line
  to the left margin
