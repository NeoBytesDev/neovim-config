-- ========================================================================
-- Options
-- ========================================================================
-- Indentation
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.colorcolumn = "100"

-- UI
vim.opt.number = true
vim.opt.cursorline = true       -- highlight the current line
vim.opt.showmode = false        -- lualine shows the mode
vim.opt.scrolloff = 8           -- keep 8 lines visible around the cursor
vim.opt.signcolumn = "yes"      -- stable gutter (no shifting when signs appear)

-- Behavior
vim.opt.keymodel = "startsel,stopsel" -- Shift+Home/End/PgUp/PgDn/arrows select
vim.opt.selectmode = "key"            -- ...into Select mode: typing replaces it
vim.opt.selection = "exclusive"       -- the char under the cursor isn't selected
                                      -- (VSCode style: Ctrl+Shift+Right on
                                      -- "foo bar" selects "foo ", not "foo b")
vim.opt.clipboard = "unnamedplus"     -- share clipboard with the system
vim.opt.undofile = true               -- persistent undo across sessions
vim.opt.ignorecase = true             -- case-insensitive search...
vim.opt.smartcase = true              -- ...unless the query has uppercase
vim.opt.swapfile = false              -- no swap files

-- Folding (treesitter-based, VSCode style)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""      -- keep syntax highlighting on the folded line
vim.opt.foldlevel = 99     -- everything unfolded on open
vim.opt.foldlevelstart = 99
vim.opt.fillchars:append({ fold = " " })

-- Leader keys (must be set before lazy)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Disable netrw (replaced by nvim-tree)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Start treesitter highlighting; treesitter indent only where it's good
vim.api.nvim_create_autocmd("FileType", {
    callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)

        -- Treesitter indent is experimental; skip languages where
        -- vim's built-in indent is better (C-family)
        local skip_ts_indent = { c = true, cpp = true, java = true }
        if skip_ts_indent[vim.bo[ev.buf].filetype] then
            -- C-family uses 'cindent', which reads 'cinkeys' rather than
            -- 'indentkeys'. Same relic there: drop "0#" so #pragma / #if
            -- keep their indentation inside a block instead of snapping
            -- to column 0.
            vim.opt_local.cinkeys:remove("0#")
        else
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end

        -- Typing a key listed in 'indentkeys' re-runs 'indentexpr' on the
        -- line. Two of the defaults are C relics that fire in every
        -- filetype: "0#" (put preprocessor lines in column 0 -- this is
        -- what breaks typing "#" at the start of an indented Python or
        -- shell comment) and "e" ("else"). Keep the brace rules and ":",
        -- which Python's dedent needs.
        vim.opt_local.indentkeys:remove({ "0#", "e" })
    end,
})

-- Don't auto-insert comment leaders on new lines
vim.api.nvim_create_autocmd("FileType", {
    callback = function()
        vim.opt_local.formatoptions:remove({ "o", "r" })
    end,
})

-- Lock terminal windows to their buffer (tab clicks can't hijack them)
vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        vim.wo.winfixbuf = true
    end,
})

-- ========================================================================
-- Diagnostics
-- ========================================================================
vim.diagnostic.config({
    virtual_text = true,     -- message at end of line
    severity_sort = true,    -- errors before warnings in the gutter
    update_in_insert = true, -- keep diagnostics live while typing
})

-- ========================================================================
-- Keymaps
-- ========================================================================
-- Mode letters below: "x" = Visual only, "s" = Select only.
-- ("v" means *both*, which breaks Select mode: the RHS gets typed as text
-- over the selection instead of running as a command.)
local map = vim.keymap.set

-- Select mode has its own mode letters; getregion() and friends only know
-- Visual's. Maps either kind to the Visual letter.
local visual_kind = {
    v = "v", V = "V", ["\22"] = "\22", -- Visual, line, block
    s = "v", S = "V", ["\19"] = "\22", -- the Select equivalents
}

-- Ctrl+3 sends the terminal's ^[ (plain <Esc>) and can't be intercepted
-- there. In GUIs / kitty-protocol terminals it arrives as its own key.
map({ "n", "i", "x", "s" }, "<C-3>", "<Nop>", { desc = "Disabled" })

-- Folding
map({ "n", "x" }, "<A-f>", "za",      { desc = "Toggle fold" })
map("i",          "<A-f>", "<C-o>za", { desc = "Toggle fold" })
map("n", "<leader>zr", "zR", { desc = "Unfold all" })
map("n", "<leader>zm", "zM", { desc = "Fold all" })

-- Save file (and return to normal mode)
map("n",          "<C-s>", "<cmd>w<cr>",      { desc = "Save file" })
map("i",          "<C-s>", "<esc><cmd>w<cr>", { desc = "Save file" })
map({ "x", "s" }, "<C-s>", "<esc><cmd>w<cr>", { desc = "Save file" })

-- Quit nvim entirely (asks about unsaved files)
map("n", "<leader>q", "<cmd>confirm qa<cr>", { desc = "Quit nvim" })

-- Indent / dedent
map("n", "<Tab>",   ">>",    { desc = "Indent line" })
map("n", "<S-Tab>", "<<",    { desc = "Dedent line" })
map("i", "<S-Tab>", "<C-d>", { desc = "Dedent line" })

-- Feeding ">gv" as keys is unsafe from Select mode: the ">" operator hands
-- Select mode back when it's done, so the trailing "gv" is typed over the
-- selection as text instead of reselecting it. Drop the selection first
-- (which sets '< and '>), shift the range with the Ex command, then
-- reselect from Normal mode -- no key ever runs in a mode that could take
-- it as input. Visual and Select share the path, so they can't drift.
local function shift_selection(dir)
    return function()
        local select = vim.api.nvim_get_mode().mode:find("^[sS\19]") ~= nil
        local shift  = string.rep(dir, vim.v.count1) -- 3<Tab> = three levels

        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
        vim.cmd("silent '<,'>" .. shift)
        vim.cmd("normal! gv")

        -- gv comes back in whichever mode the selection was made in;
        -- flip only if that isn't the one we started from.
        local mode = vim.api.nvim_get_mode().mode
        local now_select = mode:find("^[sS\19]") ~= nil
        local now_visual = mode:find("^[vV\22]") ~= nil
        if (now_select or now_visual) and now_select ~= select then
            vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "nx", false)
        end
    end
end

map({ "x", "s" }, "<Tab>",   shift_selection(">"), { desc = "Indent selection" })
map({ "x", "s" }, "<S-Tab>", shift_selection("<"), { desc = "Dedent selection" })

-- Select all
map({ "n", "i", "x", "s" }, "<C-a>", "<esc>gg0vG$<C-g>", { desc = "Select all" })

-- Copy / cut / paste (system clipboard)
-- Visual "P" pastes without clobbering the clipboard with what it replaced,
-- so pasting the same text twice in a row works.
map("n", "<C-c>", '"+yy',     { desc = "Copy line" })
map("x", "<C-c>", '"+y',      { desc = "Copy selection" })
map("s", "<C-c>", '<C-g>"+y', { desc = "Copy selection" })

map("n", "<C-x>", '"+dd',     { desc = "Cut line" })
map("x", "<C-x>", '"+d',      { desc = "Cut selection" })
map("s", "<C-x>", '<C-g>"+d', { desc = "Cut selection" })

map("n", "<C-v>", '"+p',      { desc = "Paste" })
map("x", "<C-v>", '"+P',      { desc = "Paste over selection" })
map("s", "<C-v>", '<C-g>"+P', { desc = "Paste over selection" })
map("i", "<C-v>", "<C-g>u<C-r><C-o>+", { desc = "Paste" }) -- <C-o>: paste literally, no re-indent

-- Undo / redo
-- <cmd>undo<cr> runs the command without leaving insert mode; <C-o>u drops
-- out and back in, which is what was moving the cursor.
map("n",          "<C-z>", "u",                     { desc = "Undo" })
map("i",          "<C-z>", "<cmd>undo<cr>",         { desc = "Undo" })
map({ "x", "s" }, "<C-z>", "<esc><cmd>undo<cr>",    { desc = "Undo" })

for _, key in ipairs({ "<C-y>", "<C-S-z>" }) do
    map("n",          key, "<C-r>",                  { desc = "Redo" })
    map("i",          key, "<cmd>redo<cr>",          { desc = "Redo" })
    map({ "x", "s" }, key, "<esc><cmd>redo<cr>",     { desc = "Redo" })
end

-- Vim undoes a whole insert session at once; VSCode undoes small chunks.
-- Break the undo block after these keys so <C-z> takes back a word or a
-- clause instead of everything you just typed.
for _, key in ipairs({ "<Space>", ".", ",", ";", ":" }) do
    map("i", key, key .. "<C-g>u", { desc = "Undo breakpoint" })
end

-- Toggle comment (VSCode style)
-- Visual and Select differ only in how the selection got made, so route
-- every mode through one function instead of a string mapping per mode.
local function toggle_comment()
    local mode   = vim.api.nvim_get_mode().mode
    local select = mode:find("^[sS\19]") ~= nil
    local visual = select or mode:find("^[vV\22]") ~= nil

    if not visual then
        vim.cmd("normal gcc") -- no "!": gcc is a mapping, not a builtin
        return
    end

    -- Drop the selection so '< and '> are set, comment that range, restore.
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    vim.cmd("normal gvgc")
    vim.cmd("normal! gv")

    if select then
        vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "nx", false)
    end
end

for _, key in ipairs({ "<C-_>", "<C-/>", "<A-c>" }) do
    map({ "n", "i", "x", "s" }, key, toggle_comment, { desc = "Toggle comment" })
end

-- ------------------------------------------------------------------
-- Move line / selection up and down
-- ------------------------------------------------------------------
-- <A-Up>/<A-Down> used to do this too; they now add cursors (see the
-- multicursor plugin below), so moving lines is Ctrl+Shift+Arrow only.
-- Note that <C-S-Up> needs a GUI or a kitty-protocol terminal to arrive as
-- its own key -- plain terminals send the same bytes as <Up>.
map("n", "<C-S-Up>",   "<cmd>m .-2<cr>==",          { desc = "Move line up" })
map("i", "<C-S-Up>",   "<esc><cmd>m .-2<cr>==gi",   { desc = "Move line up" })
map("n", "<C-S-Down>", "<cmd>m .+1<cr>==",          { desc = "Move line down" })
map("i", "<C-S-Down>", "<esc><cmd>m .+1<cr>==gi",   { desc = "Move line down" })

-- Selections are moved in Lua rather than with ":m '<,'>" + "gv=gv". The
-- marks and the "=" operator don't agree with 'selection=exclusive' about
-- where a selection ends, which left lines behind. Instead:
--   1. the lines are read straight from the live selection,
--   2. moved with one nvim_buf_set_lines() call (one undo step),
--   3. and the selection is put back on the same text, without ever
--      leaving Visual/Select mode -- so nothing can be typed over it.
-- Moved lines keep their indentation exactly (no re-indent).
local function move_selection(dir) -- -1 = up, 1 = down
    return function()
        local mode   = vim.api.nvim_get_mode().mode
        local kind   = visual_kind[mode]
        local select = mode:find("^[sS\19]") ~= nil
        if not kind then
            return
        end

        local a = vim.fn.getpos("v") -- anchor: { buf, line, col (1-based), off }
        local c = vim.fn.getpos(".") -- cursor
        local first = math.min(a[2], c[2])
        local last  = math.max(a[2], c[2])

        -- A charwise selection ending at the very start of a line selects
        -- nothing on that line, so (like VSCode) that line stays put.
        if kind == "v" and vim.o.selection == "exclusive" and first < last then
            local later = a[2] > c[2] and a or c
            if later[3] == 1 then
                last = last - 1
            end
        end

        -- How far we can actually go (3<C-S-Down> = three lines).
        local count = vim.v.count1
        local total = vim.api.nvim_buf_line_count(0)
        local shift
        if dir < 0 then
            shift = math.max(first - count, 1) - first
        else
            shift = math.min(last + count, total) - last
        end
        if shift == 0 then
            return -- already at the top / bottom of the file
        end

        -- Swap the block with the lines it moves over, in one edit.
        local get   = function(s, e) return vim.api.nvim_buf_get_lines(0, s, e, true) end
        local block = get(first - 1, last)
        local lines
        if shift > 0 then
            lines = get(last, last + shift)
            vim.list_extend(lines, block)
            vim.api.nvim_buf_set_lines(0, first - 1, last + shift, true, lines)
        else
            lines = block
            vim.list_extend(lines, get(first - 1 + shift, first - 1))
            vim.api.nvim_buf_set_lines(0, first - 1 + shift, last, true, lines)
        end

        -- Re-anchor the selection on the moved text. "o" swaps the anchor
        -- and the cursor, so: cursor to the new anchor spot, "o" (makes it
        -- the anchor), then cursor to its own new spot. "o" is a Visual
        -- command -- in Select mode it would be typed -- so hop to Visual
        -- for it and back afterwards.
        if select then
            vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "nx", false)
        end
        vim.api.nvim_win_set_cursor(0, { a[2] + shift, a[3] - 1 })
        vim.api.nvim_feedkeys("o", "nx", false)
        vim.api.nvim_win_set_cursor(0, { c[2] + shift, c[3] - 1 })
        if select then
            vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "nx", false)
        end
    end
end

map({ "x", "s" }, "<C-S-Up>",   move_selection(-1), { desc = "Move selection up" })
map({ "x", "s" }, "<C-S-Down>", move_selection(1),  { desc = "Move selection down" })

-- Splits
map("n", "<leader>v", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>h", "<cmd>split<cr>",  { desc = "Horizontal split" })

-- ------------------------------------------------------------------
-- Buffer tabs (Firefox style)
-- ------------------------------------------------------------------
-- <leader>1 .. <leader>9 jump to the Nth tab in the bufferline, in the
-- order it's drawn; <leader>0 goes to the last one, however many there
-- are. Normal mode only, so Space stays a plain space everywhere else.
--
-- Splits are untouched: bufferline swaps the buffer shown in the *current*
-- window and never opens, closes or focuses another one.
--
-- Windows that are pinned to their buffer ('winfixbuf': terminals, and by
-- extension anything the TermOpen autocmd above touched) can't be switched
-- at all, and neither can the tree -- pressing the key there would just
-- throw. Hop to the first real code window and switch that one instead,
-- which is what clicking a tab does anyway.
local function is_code_win(win)
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.api.nvim_win_get_config(win).relative == ""
        and not vim.wo[win].winfixbuf
        and vim.bo[buf].buftype == ""
        and vim.bo[buf].filetype ~= "NvimTree"
end

local function goto_tab(n)
    return function()
        if not is_code_win(0) then
            local target
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if is_code_win(w) then
                    target = w
                    break
                end
            end
            if not target then
                return -- nothing but terminals / the tree open
            end
            vim.api.nvim_set_current_win(target)
        end

        -- Second argument: treat n as a position in the tabline rather
        -- than an ordinal buffer number, so it matches what you see.
        -- -1 is "the last tab".
        local ok, bufferline = pcall(require, "bufferline")
        if ok then
            bufferline.go_to(n, true)
        end
    end
end

for i = 1, 9 do
    map("n", "<leader>" .. i, goto_tab(i), { desc = "Go to tab " .. i })
end
map("n", "<leader>0", goto_tab(-1), { desc = "Go to last tab" })

-- ------------------------------------------------------------------
-- Word-wise movement and selection (VSCode style)
-- ------------------------------------------------------------------
-- <C-Left>/<C-Right> jump word to word; add Shift to select while you go.
-- Neither ever crosses a line boundary: past the last word the cursor
-- stops at end of line, before the first word at column 1.
--
-- The target is computed here instead of with "normal! w"/"b", so the
-- same code works in every mode and simply sets the cursor -- in Visual
-- or Select mode that extends the selection, everywhere else it moves.

-- Character classes, the way w/b see them: 0 = blank, 1 = keyword
-- ('iskeyword', plus every non-ASCII byte so a multibyte character is
-- never split in half), 2 = punctuation.
local function char_class(byte)
    if byte == 32 or byte == 9 then
        return 0
    end
    if byte >= 128 or vim.fn.match(string.char(byte), "\\k") == 0 then
        return 1
    end
    return 2
end

-- Where a word jump from 0-based column `col` lands on this line.
local function word_target(line, col, dir)
    local len = #line
    local i   = col + 1 -- 1-based byte index

    if dir == "right" then
        if i > len then
            return len
        end
        -- Skip the rest of the current word (or punctuation run)...
        local c = char_class(line:byte(i))
        if c ~= 0 then
            while i <= len and char_class(line:byte(i)) == c do
                i = i + 1
            end
        end
        -- ...then the blanks after it, landing on the next word's start.
        while i <= len and char_class(line:byte(i)) == 0 do
            i = i + 1
        end
        return i - 1
    end

    -- Left: step back over blanks, then to the start of that word.
    i = math.min(i, len + 1) - 1
    while i >= 1 and char_class(line:byte(i)) == 0 do
        i = i - 1
    end
    if i < 1 then
        return 0
    end
    local c = char_class(line:byte(i))
    while i > 1 and char_class(line:byte(i - 1)) == c do
        i = i - 1
    end
    return i - 1
end

local function word_move(dir)
    local pos  = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local mode = vim.api.nvim_get_mode().mode

    -- Insert mode and (exclusive) selections may sit one past the last
    -- character; Normal mode stops on it.
    local max = #line
    if not (mode:find("^i") or mode:find("^[vVsS\22\19]")) then
        max = math.max(#line - 1, 0)
    end

    local col = math.min(word_target(line, pos[2], dir), max)
    vim.api.nvim_win_set_cursor(0, { pos[1], col })
end

-- Reachable from key strings, so mappings below can run it mid-sequence
-- (e.g. right after "v") without needing remap.
_G.WordMotion = { move = word_move }

local function move_keys(dir)
    return ("<Cmd>lua WordMotion.move(%q)<CR>"):format(dir)
end

for key, dir in pairs({ Left = "left", Right = "right" }) do
    local function move() word_move(dir) end

    -- Plain Ctrl+Arrow: move. With a selection active, drop it first and
    -- move from the cursor, like VSCode.
    map({ "n", "i" }, "<C-" .. key .. ">", move, { desc = "Word " .. dir })
    map({ "x", "s" }, "<C-" .. key .. ">", "<Esc>" .. move_keys(dir),
        { desc = "Word " .. dir })

    -- Ctrl+Shift+Arrow: start a selection at the cursor (in Select mode,
    -- so typing replaces it), or extend the one that's already there.
    map("n", "<C-S-" .. key .. ">", "v" .. move_keys(dir) .. "<C-g>",
        { desc = "Select word " .. dir })
    map({ "x", "s" }, "<C-S-" .. key .. ">", move, { desc = "Select word " .. dir })

    -- From Insert mode, <C-o>v starts a selection that returns to Insert
    -- when it ends. <C-o> at end of line nudges the cursor one left,
    -- which would leave the last character out of the anchor, so in that
    -- case step back onto the end ("l" -- allowed in Visual mode) and
    -- swap ends ("o") to put the anchor there.
    map("i", "<C-S-" .. key .. ">", function()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local len = #vim.api.nvim_get_current_line()
        local start = (len > 0 and col >= len) and "<C-o>vlo" or "<C-o>v"
        return start .. move_keys(dir) .. "<C-g>"
    end, { expr = true, desc = "Select word " .. dir })
end

-- ------------------------------------------------------------------
-- Word-wise deletion (VSCode style)
-- ------------------------------------------------------------------
-- Insert mode's built-in <C-w> already deletes back to the start of the
-- previous word, whitespace included -- the same span VSCode removes.
-- <C-g>u in front makes each deletion its own undo step.
--
-- Which key actually arrives depends on the terminal: GUIs and
-- kitty-protocol terminals send <C-BS>, but most terminals send ^H
-- (= <C-h>) for Ctrl+Backspace. Map both in insert mode, so it works
-- either way. (That's why find-and-replace below isn't on <C-h> in
-- insert mode -- press <Esc> first, then <C-h>.)
for _, key in ipairs({ "<C-BS>", "<C-h>" }) do
    map("i", key, "<C-g>u<C-w>", { desc = "Delete word left" })
end

-- Ctrl+Delete, the other half of the pair. <C-o> at the very end of a
-- line nudges the cursor one left, which would make dw eat the last
-- character, so bail out when there's nothing to the right.
local function delete_word_right()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col >= #vim.api.nvim_get_current_line() then
        return
    end
    vim.api.nvim_feedkeys(vim.keycode("<C-g>u<C-o>dw"), "n", false)
end

map("i", "<C-Del>", delete_word_right, { desc = "Delete word right" })

-- Normal mode has no VSCode equivalent to copy, but the same span is
-- useful there; "_ keeps the deletion out of the clipboard.
map("n", "<C-BS>", '"_db',  { desc = "Delete word left" })
map("n", "<C-Del>", '"_dw', { desc = "Delete word right" })

-- ------------------------------------------------------------------
-- Find / Replace (VSCode style)
-- ------------------------------------------------------------------
-- <C-f> and <C-h> open the command line seeded with the selection, with
-- the cursor where you'd start typing; <cr> runs it. <F3> / <S-F3> walk
-- the matches, <Esc> clears the highlighting.
--
-- <C-h> is Normal / Visual / Select only: in insert mode it's taken by
-- Ctrl+Backspace (see word-wise deletion above).
--
-- Patterns are seeded with flags so only what you actually typed or
-- selected counts as a match:
--   \V     every character is literal -- "a.b" won't match "axb"
--   \C     case-sensitive, whatever 'ignorecase' and 'smartcase' say
--   \< \>  word boundaries -- "cat" won't match inside "concatenate"
-- Set this to false for substring matching, or delete the flags from the
-- command line before pressing <cr> to loosen a single search.
local exact_match = true

-- The selected lines, or nil if there's no selection.
local function selected_lines()
    local kind = visual_kind[vim.api.nvim_get_mode().mode]
    if not kind then
        return nil
    end
    local ok, lines = pcall(vim.fn.getregion,
        vim.fn.getpos("v"), vim.fn.getpos("."), { type = kind })
    return ok and #lines > 0 and lines or nil
end

-- One line of selected text, or nil -- VSCode only seeds the find box
-- from a single-line selection too.
local function selected_word(lines)
    if lines and #lines == 1 and lines[1] ~= "" then
        return lines[1]
    end
end

-- Does 'iskeyword' count this character as part of a word?
local function is_keyword(char)
    return char ~= "" and vim.fn.match(char, "\\k") == 0
end

-- Escape for use as a \V ("very nomagic") pattern, where only the
-- backslash and the / delimiter still mean anything, and wrap it in the
-- flags described above.
local function pattern_of(text)
    local prefix = "\\V\\C"
    local suffix = ""

    -- \< and \> only match next to a keyword character, so a selection
    -- like "foo(" gets a boundary on the "f" side and not the other.
    if exact_match then
        if is_keyword(vim.fn.strcharpart(text, 0, 1)) then
            prefix = prefix .. "\\<"
        end
        if is_keyword(vim.fn.strcharpart(text, vim.fn.strchars(text) - 1, 1)) then
            suffix = "\\>"
        end
    end

    return prefix .. vim.fn.escape(text, "\\/") .. suffix
end

-- feed() translates key notation; feed_raw() doesn't, so a "<" in the
-- selected text isn't read as the start of a key name.
local function feed(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
end
local function feed_raw(text)
    vim.api.nvim_feedkeys(text, "n", false)
end

-- Nothing selected: seed the flags anyway, so what you type by hand is
-- taken literally too. Word boundaries can't go here -- you'd have to
-- type between them.
local flags = "\\V\\C"

local function find()
    local word = selected_word(selected_lines())
    feed("<Esc>/") -- <Esc> first: search the file, not the selection
    feed_raw(word and pattern_of(word) or flags)
end

local function replace()
    local lines = selected_lines()
    local word  = selected_word(lines)
    feed("<Esc>") -- also sets '< and '> for the range below

    if word then
        -- Pattern is filled in; land in the replacement slot
        feed_raw(":%s/" .. pattern_of(word))
        feed_raw("//g")
        feed("<Left><Left>")
    elseif lines then
        -- Multi-line selection: substitute inside it ("find in selection")
        feed_raw(":'<,'>s/" .. flags .. "//g")
        feed("<Left><Left><Left>")
    else
        feed_raw(":%s/" .. flags .. "//g")
        feed("<Left><Left><Left>")
    end
end

map({ "n", "i", "x", "s" }, "<C-f>", find,    { desc = "Find" })
map({ "n", "x", "s" },      "<C-h>", replace, { desc = "Find and replace" })

map("n",               "<F3>",   "n",      { desc = "Next match" })
map({ "i", "x", "s" }, "<F3>",   "<esc>n", { desc = "Next match" })
map("n",               "<S-F3>", "N",      { desc = "Previous match" })
map({ "i", "x", "s" }, "<S-F3>", "<esc>N", { desc = "Previous match" })

map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Close split if there are several; otherwise close the buffer
map("n", "<C-q>", function()
    -- Only act in real code windows (not the tree, terminal, help, etc.)
    if vim.bo.buftype ~= "" or vim.bo.filetype == "NvimTree" then
        return
    end

    -- Count "real" code windows: not floating, not the tree, not terminals
    local code_wins = 0
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local cfg = vim.api.nvim_win_get_config(w)
        local buf = vim.api.nvim_win_get_buf(w)
        if cfg.relative == ""
            and vim.bo[buf].buftype == ""
            and vim.bo[buf].filetype ~= "NvimTree"
        then
            code_wins = code_wins + 1
        end
    end

    -- Multiple splits: just close this one
    if code_wins > 1 then
        vim.cmd("close")
        return
    end

    -- Single view: switch this window to another listed buffer, then delete
    local cur = vim.api.nvim_get_current_buf()
    local others = vim.tbl_filter(function(b)
        return vim.bo[b].buflisted
            and vim.bo[b].buftype == "" -- exclude terminals & friends
            and b ~= cur
    end, vim.api.nvim_list_bufs())

    if #others > 0 then
        vim.api.nvim_win_set_buf(0, others[#others])
    else
        vim.cmd("enew")
    end

    vim.cmd("bdelete " .. cur)
end, { desc = "Close split / buffer" })

-- ========================================================================
-- LSP / completion toggle
-- ========================================================================
-- :LspDisable stops the language servers, hides diagnostics and turns off
-- the completion popup; :LspEnable brings all three back. User commands
-- have to start with a capital letter, so lowercase abbreviations are set
-- up below -- typing ":lspdisable" expands to the real name.
--
-- This list is also what the lspconfig block enables at startup.
--
-- gopls belongs here even though it starts fine without it: mason-lspconfig
-- auto-enables whatever Mason has installed, so Go worked, but :LspDisable
-- only walks this list and would have left gopls running.
local lsp_servers = { "pyright", "clangd", "neocmake", "gopls" }

local function lsp_set(on)
    vim.g.lsp_enabled = on

    for _, name in ipairs(lsp_servers) do
        vim.lsp.enable(name, on)
    end

    if on then
        -- vim.lsp.enable() attaches on FileType; buffers already open have
        -- had theirs, so fire it again for them.
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
                vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
            end
        end
    else
        -- Disabling a config doesn't stop clients that are already running.
        for _, client in ipairs(vim.lsp.get_clients()) do
            client:stop()
        end
        pcall(function() require("blink.cmp").hide() end)
    end

    vim.diagnostic.enable(on)
    vim.notify("LSP " .. (on and "enabled" or "disabled"))
end

vim.api.nvim_create_user_command("LspEnable",  function() lsp_set(true)  end, {})
vim.api.nvim_create_user_command("LspDisable", function() lsp_set(false) end, {})
vim.api.nvim_create_user_command("LspToggle",  function() lsp_set(vim.g.lsp_enabled == false) end, {})

-- Type them lowercase: ':lspdisable' expands to ':LspDisable' as you hit
-- space or <cr>. The guard keeps the word from expanding mid-line (e.g.
-- inside a :s pattern).
for _, name in ipairs({ "LspEnable", "LspDisable", "LspToggle" }) do
    vim.cmd(("cnoreabbrev <expr> %s (getcmdtype() == ':' && getcmdline() ==# '%s') ? '%s' : '%s'")
        :format(name:lower(), name:lower(), name, name:lower()))
end

-- ========================================================================
-- Bootstrap lazy.nvim
-- ========================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- ========================================================================
-- Plugins
-- ========================================================================
require("lazy").setup({
    spec = {
        -- ------------------------------------------------------------
        -- UI
        -- ------------------------------------------------------------
        -- {
        --     "ellisonleao/gruvbox.nvim",
        --     priority = 1000,
        --     opts = {
        --         contrast = "hard",
        --     },
        --     config = function(_, opts)
        --         require("gruvbox").setup(opts)
        --         vim.cmd.colorscheme("gruvbox")
        --     end,
        -- },
        {
            "navarasu/onedark.nvim",
            priority = 1000,
            config = function()
                require("onedark").setup({
                    style = "darker",
                    highlights = {
                        ["@punctuation.bracket"] = { fg = "#e06c75" },
                        ["@punctuation.delimiter"] = { fg = "#e06c75" },
                    },
                })
                require("onedark").load()
            end,
        },
        {
            "nvim-lualine/lualine.nvim",
            dependencies = { "nvim-tree/nvim-web-devicons" },
            event = "VeryLazy",
            opts = {
                options = { theme = "auto" },
            },
        },
        {
            "akinsho/bufferline.nvim",
            dependencies = { "nvim-tree/nvim-web-devicons" },
            event = "VeryLazy",
            opts = {
                options = {
                    indicator = { style = "none" },
                    -- Draw the position of each tab, so <leader>N has a
                    -- number to aim at. "ordinal" is the slot in the
                    -- tabline, which is exactly what goto_tab() counts.
                    numbers = "ordinal",
                    offsets = {
                        { filetype = "NvimTree", text = "Files", separator = true },
                    },
                },
            },
        },
        {
            "lukas-reineke/indent-blankline.nvim",
            main = "ibl",
            event = "VeryLazy",
            opts = {
                scope = { enabled = false },
            },
        },
        {
            "lewis6991/gitsigns.nvim",
            event = "VeryLazy",
            opts = {},
        },

        -- ------------------------------------------------------------
        -- Navigation
        -- ------------------------------------------------------------
        {
            "nvim-telescope/telescope.nvim",
            version = "*",
            dependencies = {
                "nvim-lua/plenary.nvim",
                { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
            },
            keys = {
                { "<C-p>",      function() require("telescope.builtin").find_files() end, desc = "Find files" },
                { "<leader>fg", function() require("telescope.builtin").live_grep() end,  desc = "Live grep" },
            },
        },
        {
            "nvim-tree/nvim-tree.lua",
            dependencies = { "nvim-tree/nvim-web-devicons" }, -- needs a Nerd Font
            keys = {
                { "<C-b>", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file explorer" },
            },
            opts = {},
        },
        {
            "akinsho/toggleterm.nvim",
            keys = {
                { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal", mode = { "n", "t" } },
            },
            opts = {
                direction = "horizontal",
                start_in_insert = true, -- enter insert (terminal) mode on open
                persist_mode = false,   -- don't remember normal mode between toggles
            },
        },

        -- ------------------------------------------------------------
        -- Editing
        -- ------------------------------------------------------------
        {
            "nvim-treesitter/nvim-treesitter",
            branch = "main",
            build = ":TSUpdate",
            lazy = false,
            config = function()
                require("nvim-treesitter").install({
                    "bash", "lua", "cpp", "c", "cmake", "html", "css",
                    "javascript", "typescript", "tsx", "csv",
                    "python", "go", "gomod", "gowork", "java", "json",
                })
            end,
        },
        {
            "windwp/nvim-autopairs",
            event = "InsertEnter",
            opts = {},
        },

        -- Multiple cursors (VSCode style)
        {
            "jake-stewart/multicursor.nvim",
            branch = "1.0",
            event = "VeryLazy",
            config = function()
                local mc = require("multicursor-nvim")
                mc.setup()

                -- Add a cursor on the line above/below, keeping the column.
                local function add_cursor(dir)
                    return function()
                        mc.lineAddCursor(dir)
                    end
                end

                -- Same thing from insert mode, which has to leave insert,
                -- add the cursor, then come back.
                --
                -- This must not be done with nvim_feedkeys(..., "x"): "x"
                -- means "run these keys now, until the typeahead is empty",
                -- and entering insert mode never empties it -- it sits there
                -- waiting for input. The call blocks inside the callback,
                -- swallows what you type, and leaves the buffer in insert
                -- mode while lualine still says normal.
                --
                -- An <expr> mapping sidesteps all of it: the keys are handed
                -- back to Nvim and run in order, exactly as if typed.
                local function add_cursor_insert(dir)
                    return function()
                        -- <Esc> lands one character to the left, so "a"
                        -- (append after it) is what puts us back where we
                        -- were -- except in column 0, where there's nothing
                        -- to the left and "i" is the one.
                        local back = vim.api.nvim_win_get_cursor(0)[2] == 0 and "i" or "a"
                        return ("<Esc><Cmd>lua require('multicursor-nvim').lineAddCursor(%d)<CR>%s")
                            :format(dir, back)
                    end
                end

                local expr = { expr = true, replace_keycodes = true }

                map({ "n", "x" }, "<A-Up>",   add_cursor(-1), { desc = "Add cursor above" })
                map({ "n", "x" }, "<A-Down>", add_cursor(1),  { desc = "Add cursor below" })
                map("i", "<A-Up>", add_cursor_insert(-1),
                    vim.tbl_extend("force", expr, { desc = "Add cursor above" }))
                map("i", "<A-Down>", add_cursor_insert(1),
                    vim.tbl_extend("force", expr, { desc = "Add cursor below" }))

                -- Ctrl+D: cursor at the next occurrence of the word under the
                -- cursor / the selection. (Shadows the half-page scroll.)
                map({ "n", "x" }, "<C-d>", function() mc.matchAddCursor(1) end,
                    { desc = "Add cursor at next match" })
                map({ "n", "x" }, "<A-d>", function() mc.matchSkipCursor(1) end,
                    { desc = "Skip to next match" })

                -- Only active while extra cursors exist, so this <Esc> takes
                -- priority over the nohlsearch one until they're gone.
                mc.addKeymapLayer(function(layer)
                    layer({ "n", "x" }, "<Esc>", function()
                        if mc.cursorsEnabled() then
                            mc.clearCursors()
                        else
                            mc.enableCursors()
                        end
                    end, { desc = "Clear extra cursors" })
                end)

                local hl = vim.api.nvim_set_hl
                hl(0, "MultiCursorCursor",         { reverse = true })
                hl(0, "MultiCursorVisual",         { link = "Visual" })
                hl(0, "MultiCursorSign",           { link = "SignColumn" })
                hl(0, "MultiCursorMatchPreview",   { link = "Search" })
                hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
                hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
                hl(0, "MultiCursorDisabledSign",   { link = "SignColumn" })
            end,
        },

        -- TODO / FIXME / HACK highlighting (needs ripgrep for the pickers)
        {
            "folke/todo-comments.nvim",
            dependencies = { "nvim-lua/plenary.nvim" },
            event = { "BufReadPost", "BufNewFile" },
            keys = {
                { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find TODOs" },
                { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
                { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous TODO" },
            },
            opts = {
                signs = false, -- gitsigns already owns the gutter
                -- The default patterns require a colon ("TODO:"). These
                -- drop it, so a bare "TODO" lights up too. The trailing
                -- word boundary (> in Vim regex, \b in ripgrep) keeps
                -- e.g. "NOTEBOOK" from matching NOTE. Only comments are
                -- checked, so "todo" in code stays plain.
                highlight = {
                    pattern = [[.*<(KEYWORDS)>]], -- Vim regex (very magic)
                },
                search = {
                    pattern = [[\b(KEYWORDS)\b]], -- ripgrep regex, for ]t [t and the picker
                },
            },
        },

        -- ------------------------------------------------------------
        -- LSP & completion
        -- ------------------------------------------------------------
        {
            "neovim/nvim-lspconfig",
            dependencies = {
                { "mason-org/mason.nvim", opts = {} },
                { "mason-org/mason-lspconfig.nvim", opts = {} },
            },
            config = function()
                -- Nvim leaves LSP file watching off on Linux (inotify runs
                -- out of watches on big trees), which means a server never
                -- hears about files that appear after it started. The buffer
                -- itself still attaches -- what's missing is the *project*
                -- view: gopls keeps the package list it built at startup, so
                -- a brand new .go file isn't part of any package and nothing
                -- in it shows up in completions until nvim is restarted.
                -- Pyright has the same problem with new .py files.
                --
                -- "*" is the config every server inherits, so this also
                -- covers the ones mason-lspconfig enables on its own rather
                -- than only the ones named in lsp_servers.
                vim.lsp.config("*", {
                    capabilities = {
                        workspace = {
                            didChangeWatchedFiles = { dynamicRegistration = true },
                        },
                    },
                })

                -- Same list :LspEnable / :LspDisable work from.
                for _, name in ipairs(lsp_servers) do
                    vim.lsp.enable(name)
                end
                vim.g.lsp_enabled = true
            end,
        },
        {
            "saghen/blink.cmp",
            version = "1.*",
            dependencies = { "rafamadriz/friendly-snippets" },
            opts = {
                -- Re-checked on every trigger, so :LspDisable silences the
                -- popup without a restart.
                enabled = function() return vim.g.lsp_enabled ~= false end,
                keymap = { preset = "enter" },
                completion = {
                    documentation = { auto_show = true },
                },
            },
        },
        {
            "ray-x/lsp_signature.nvim",
            event = "InsertEnter",
            opts = {
                bind = true,
                hint_enable = false,
                handler_opts = { border = "rounded" },
                floating_window_above_cur_line = true,
                toggle_key = "<C-g>",
                select_signature_key = "<A-n>",
                fix_pos = false,     -- don't pin the window open until all params are filled
                close_timeout = 200, -- ms after the last parameter is entered
            },
            config = function(_, opts)
                require("lsp_signature").setup(opts)

                -- The float is created via vim.lsp.util.open_floating_preview,
                -- which records its window id in b:lsp_floating_preview.
                local function sig_win()
                    local w = vim.b.lsp_floating_preview
                    if w and vim.api.nvim_win_is_valid(w) then
                        return w
                    end
                end

                -- Unclosed "(" before the cursor, on this line only?
                local function in_args()
                    return vim.fn.searchpairpos("(", "", ")", "nbW", "", vim.fn.line("."))[1] ~= 0
                end

                local anchor -- { buf, line } the float was opened on

                vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertLeave" }, {
                    group = vim.api.nvim_create_augroup("SignatureAutoClose", { clear = true }),
                    callback = function(ev)
                        local win = sig_win()
                        if not win then
                            anchor = nil
                            return
                        end

                        local line = vim.fn.line(".")
                        anchor = anchor or { buf = ev.buf, line = line }

                        if ev.event == "InsertLeave"
                            or ev.buf ~= anchor.buf
                            or line ~= anchor.line
                            or not in_args()
                        then
                            pcall(vim.api.nvim_win_close, win, true)
                            anchor = nil
                        end
                    end,
                })
            end,
        },
		-- Markdown preview in the browser (live reload + scroll sync)
        -- <leader>mp toggles it, in markdown files only. Ctrl+Shift+V
        -- (VSCode's key) is left alone: most terminals take it for paste.
        {
            "iamcco/markdown-preview.nvim",
            cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
            ft = { "markdown" },
            -- Downloads a prebuilt binary, so Node/yarn aren't needed.
            build = function() vim.fn["mkdp#util#install"]() end,
            init = function()
                vim.g.mkdp_filetypes = { "markdown" }
                vim.g.mkdp_theme = "dark"   -- match the editor
                vim.g.mkdp_auto_close = 1   -- close the tab when you leave the buffer
                vim.g.mkdp_echo_preview_url = 1 -- print the URL, handy if no browser opens
            end,
            keys = {
                { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown",
                  desc = "Toggle markdown preview" },
            },
        },
    },
    checker = { enabled = true },
})
