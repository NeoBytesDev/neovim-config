# VSCode-style Neovim

A single-file Neovim config that keeps Vim underneath but puts a VSCode keymap on top:
`Ctrl+S` saves, `Ctrl+C`/`Ctrl+X`/`Ctrl+V` use the system clipboard, `Ctrl+Z` undoes in
small chunks, `Ctrl+F`/`Ctrl+H` find and replace, `Ctrl+Backspace` deletes a word,
`Alt+↑`/`Alt+↓` stack multiple cursors, `Shift+arrows` select, and typing over a
selection replaces it. Plugins are managed by
[lazy.nvim](https://github.com/folke/lazy.nvim) and bootstrap themselves on first launch.

Highlights: onedark (darker), lualine + bufferline, nvim-tree, telescope, toggleterm,
treesitter (incl. folding), multicursor, todo-comments, nvim-autopairs, gitsigns,
indent-blankline, and LSP via `nvim-lspconfig` + `mason` with `blink.cmp` for completion.

## Requirements

- Neovim 0.11+ (uses `vim.lsp.enable`, `winfixbuf`, treesitter `main` branch)
- A **Nerd Font** in your terminal (icons in the tree, tabline and statusline)
- `git`, a C compiler and `make` (treesitter parsers, `telescope-fzf-native`)
- `ripgrep` for live grep and the TODO picker, `fd` recommended for file finding
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
bufferline can't hijack the terminal split. The terminal opens straight into insert mode
and doesn't remember normal mode between toggles.

## Editing

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>C</kbd> | N V S | Copy line / selection to the system clipboard |
| <kbd>Ctrl</kbd>+<kbd>X</kbd> | N V S | Cut line / selection |
| <kbd>Ctrl</kbd>+<kbd>V</kbd> | N I V S | Paste (over the selection in V/S) |
| <kbd>Ctrl</kbd>+<kbd>Z</kbd> | N I V S | Undo |
| <kbd>Ctrl</kbd>+<kbd>Y</kbd> or <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd> | N I V S | Redo |
| <kbd>Ctrl</kbd>+<kbd>Backspace</kbd> | N I | Delete the word before the cursor |
| <kbd>Ctrl</kbd>+<kbd>Delete</kbd> | N I | Delete the word after the cursor |
| <kbd>Tab</kbd> | N V S | Indent line / selection (keeps the selection) |
| <kbd>Shift</kbd>+<kbd>Tab</kbd> | N I V S | Dedent line / selection |
| <kbd>Ctrl</kbd>+<kbd>/</kbd> or <kbd>Alt</kbd>+<kbd>C</kbd> | N I V S | Toggle comment |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>↑</kbd> / <kbd>↓</kbd> | N I V S | Move line / selection up / down (re-indents) |

Moving lines is on <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+arrows only —
<kbd>Alt</kbd>+arrows now add cursors instead. That keycode needs a GUI client or a
kitty-protocol terminal to arrive as its own key; plain terminals send the same bytes as
a bare <kbd>↑</kbd>. See [Terminal quirks](#terminal-quirks-worth-knowing).

Pasting over a selection uses visual `P`, so the clipboard is *not* replaced by whatever
you pasted over — pasting the same text twice in a row works as expected. Insert-mode
paste is literal (`<C-r><C-o>+`), so indented blocks don't get re-indented on the way in.

Word deletion is Vim's built-in `<C-w>` with an undo breakpoint in front, so it removes
the same span VSCode does — the word plus any whitespace between it and the cursor — and
each deletion can be undone on its own. In normal mode the deleted text goes to the black
hole register, so it doesn't clobber your clipboard.

Undo is chunked like VSCode's: an undo breakpoint is inserted after <kbd>Space</kbd>,
`.`, `,`, `;` and `:`, so `Ctrl+Z` takes back a word or a clause instead of the entire
insert session. Undoing from insert mode uses `<cmd>undo<cr>`, which keeps you in insert
mode and leaves the cursor where it was. Undo history is persistent across sessions
(`undofile`), and there are no swap files.

## Multiple cursors

[multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim) provides VSCode's
two multi-cursor workflows: stacking cursors down a column, and putting one on each
occurrence of a word.

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Alt</kbd>+<kbd>↑</kbd> / <kbd>Alt</kbd>+<kbd>↓</kbd> | N I V | Add a cursor on the line above / below |
| <kbd>Ctrl</kbd>+<kbd>D</kbd> | N V | Add a cursor at the next occurrence of the word under the cursor |
| <kbd>Alt</kbd>+<kbd>D</kbd> | N V | Skip this occurrence and jump to the next |
| <kbd>Esc</kbd> | N V | Collapse back to a single cursor |

Stack as many cursors as you need, then type. From insert mode you can keep going without
interruption — the mapping steps out, adds the cursor and drops you back at the same
column. From normal mode press `i`, `a`, `A` or `c` first and every cursor enters insert
together.

The insert session is **replayed at the other cursors when you leave insert mode**, so
while typing you'll only see the text at the main cursor. Press <kbd>Esc</kbd> and the
rest fill in. This is the one place the behaviour visibly differs from VSCode, where all
cursors update live.

Normal-mode commands replay at every cursor, which is where this beats VSCode: `A;`
appends a semicolon to each line, `dw` deletes a word at each, `ciw` changes the word
under each, `>>` indents each. Motions work too — the cursors move independently and stay
wherever they land.

Two things to watch:

- <kbd>Ctrl</kbd>+<kbd>D</kbd> shadows Vim's half-page scroll. `<C-f>`/`<C-b>` are also
  taken by find, so page-wise scrolling is <kbd>PgUp</kbd>/<kbd>PgDn</kbd> here.
- Because `keymodel=startsel` puts shifted motions in **Select** mode, which multicursor
  doesn't drive, the cursor bindings are mapped for normal and Visual only. Press
  <kbd>Ctrl</kbd>+<kbd>G</kbd> to flip a Select-mode selection to Visual first.

The <kbd>Esc</kbd> binding is a keymap *layer* that only exists while extra cursors are
alive, so it takes priority over the search-highlight one until the cursors are gone.
From insert mode it takes two presses: the first leaves insert (and replays the edit),
the second clears the cursors.

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

## Find and replace

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>F</kbd> | N I V S | Find — opens `/`, seeded with the selection |
| <kbd>Ctrl</kbd>+<kbd>H</kbd> | N I V S | Replace — opens `:%s/…/…/g`, seeded with the selection |
| <kbd>F3</kbd> | N I V S | Next match |
| <kbd>Shift</kbd>+<kbd>F3</kbd> | N I V S | Previous match |
| <kbd>Esc</kbd> | N | Clear search highlighting |

Both bindings leave the current mode first, so they always act on the file rather than on
the selection, then drop you on the command line with the cursor where you'd start
typing; <kbd>Enter</kbd> runs it.

A **single-line** selection seeds the search or replace pattern, the way VSCode fills its
find box from the selection. A **multi-line** selection means something different for
<kbd>Ctrl</kbd>+<kbd>H</kbd>: instead of seeding a pattern, it scopes the substitution to
the selected lines (`:'<,'>s///g`) — VSCode's "find in selection". With no selection you
get a plain `:%s///g` over the whole file.

### Exact matching

Patterns are seeded with three flags so only what you actually typed or selected counts
as a match:

| Flag | Effect |
| --- | --- |
| `\V` | Every character is literal — `a.b` won't match `axb` |
| `\C` | Case-sensitive, whatever `ignorecase` and `smartcase` say |
| `\<` `\>` | Word boundaries — `cat` won't match inside `concatenate` |

Boundaries are only added on a side where the text actually ends in a keyword character,
since `\<`/`\>` can't match next to punctuation: selecting `foo(` gets `\<foo(` with no
closing boundary. When there's no selection, `\V\C` is seeded anyway so hand-typed
patterns are literal too — word boundaries can't be, as you'd have to type between them.

Set `exact_match = false` near the top of the find/replace section for substring
matching, or just delete the flags from the command line to loosen a single search.

Note that `\V` governs the *pattern* only. In the replacement half, `&` still means "the
whole match" and `~` means "the previous replacement" — escape them as `\&` and `\~` if
you want them typed out literally.

## TODO comments

[todo-comments.nvim](https://github.com/folke/todo-comments.nvim) colours annotation
keywords in comments.

| Keyword | Also matches | Colour |
| --- | --- | --- |
| `TODO:` | — | info |
| `FIX:` | `FIXME:` `BUG:` `FIXIT:` `ISSUE:` | error |
| `HACK:` | — | warning |
| `WARN:` | `WARNING:` `XXX:` | warning |
| `PERF:` | `OPTIM:` `PERFORMANCE:` `OPTIMIZE:` | default |
| `NOTE:` | `INFO:` | hint |
| `TEST:` | `TESTING:` `PASSED:` `FAILED:` | test |

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Space</kbd> <kbd>F</kbd> <kbd>T</kbd> | N | List every TODO in the project (telescope) |
| <kbd>]</kbd> <kbd>T</kbd> | N | Jump to the next TODO |
| <kbd>[</kbd> <kbd>T</kbd> | N | Jump to the previous TODO |

Three conditions have to hold for a keyword to light up:

- **The colon is required.** A bare `TODO` stays plain text; the colour appears the
  moment you type `TODO:`. Re-highlighting runs off `nvim_buf_attach`, which fires on
  every keystroke, so it happens as you type rather than on save. Whitespace before the
  colon is allowed, so `TODO :` works too.
- **It has to be inside a real comment.** `comments_only` is on and uses treesitter to
  check, so `TODO:` inside a string literal stays plain. Filetypes without a parser fall
  back to a plain regex match.
- **Keywords are case-sensitive.** `todo:` and `Fixme:` don't trigger.

Signs are turned off so gitsigns keeps the gutter to itself, and the pickers need
`ripgrep` on your `PATH`.

## Folding

Folding is treesitter-based and everything starts unfolded.

| Keys | Modes | Action |
| --- | --- | --- |
| <kbd>Alt</kbd>+<kbd>F</kbd> | N I V | Toggle fold under the cursor |
| <kbd>Space</kbd> <kbd>Z</kbd> <kbd>R</kbd> | N | Unfold all |
| <kbd>Space</kbd> <kbd>Z</kbd> <kbd>M</kbd> | N | Fold all |

Folded lines keep their syntax highlighting instead of being replaced by the usual dashed
summary line.

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
- <kbd>Ctrl</kbd>+<kbd>Backspace</kbd> is mapped as `<C-BS>`, which only arrives as its
  own key in GUI clients and kitty-protocol terminals. Most terminals send `^H` instead,
  and that keycode belongs to <kbd>Ctrl</kbd>+<kbd>H</kbd> (replace) — one key can't be
  both. On those terminals, use insert mode's built-in <kbd>Ctrl</kbd>+<kbd>W</kbd>,
  which deletes the same span.
- <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+arrows have the same requirement, so moving lines
  needs a GUI or kitty protocol too. To check what your terminal actually sends, run
  `:lua vim.print(vim.fn.getcharstr())` and press the key.
- <kbd>Ctrl</kbd>+<kbd>3</kbd> is bound to nothing on purpose. Most terminals send it as
  a plain <kbd>Esc</kbd> and it can't be intercepted; in GUI clients and
  kitty-protocol terminals it arrives as a distinct key, and the no-op keeps behaviour
  consistent.
- <kbd>Alt</kbd>+arrow bindings need a terminal that passes Alt through (or a GUI
  client). Most do.

## Other defaults

- 4-space indentation, colour column at 100
- onedark in its `darker` style, with brackets and delimiters overridden to red; a
  gruvbox block is left commented out in the config if you want to switch back
- Line numbers, current-line highlight, 8 lines of context kept around the cursor, and a
  permanently visible sign column so the text doesn't shift when a diagnostic appears
- The mode indicator is left to lualine (`showmode` is off)
- `ignorecase` + `smartcase` search (find and replace override this with `\C`)
- System clipboard shared with the unnamed register (`unnamedplus`)
- Comment leaders are *not* auto-inserted on new lines
- `netrw` is disabled in favour of nvim-tree
- Treesitter indent is used everywhere except C/C++/Java, where Vim's `cindent` is
  better; in both cases the old C-era rule that snaps `#` to column 0 is removed, so
  typing `#` at the start of an indented Python or shell comment no longer jumps the line
  to the left margin
- Treesitter parsers installed on first run: bash, lua, c, cpp, cmake, html, css,
  javascript, typescript, tsx, csv, python, go, java, json
- lazy.nvim's update checker is on, so you'll be told when plugin updates are available
