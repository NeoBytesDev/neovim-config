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

-- Run a Visual-mode command on a Select-mode selection, then return to
-- Select mode. <C-g> toggles Select <-> Visual; where a command leaves us
-- varies, so check the mode afterwards and only flip back if needed.
local function keep_select(keys, remap)
    return function()
        vim.api.nvim_feedkeys(vim.keycode("<C-g>" .. keys), (remap and "m" or "n") .. "x", false)
        if vim.api.nvim_get_mode().mode:find("^[vV\22]") then
            vim.api.nvim_feedkeys(vim.keycode("<C-g>"), "nx", false)
        end
    end
end

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
map("x", "<Tab>",   ">gv",   { desc = "Indent selection" })
map("x", "<S-Tab>", "<gv",   { desc = "Dedent selection" })
map("s", "<Tab>",   keep_select(">gv"),      { desc = "Indent selection" })
map("s", "<S-Tab>", keep_select("<lt>gv"),   { desc = "Dedent selection" })

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

-- Move line / selection up and down
for _, key in ipairs({ "<A-Up>", "<C-S-Up>" }) do
    map("n", key, "<cmd>m .-2<cr>==",             { desc = "Move line up" })
    map("i", key, "<esc><cmd>m .-2<cr>==gi",      { desc = "Move line up" })
    map("x", key, ":m '<-2<cr>gv=gv",             { desc = "Move selection up" })
    map("s", key, keep_select(":m '<lt>-2<cr>gv=gv"), { desc = "Move selection up" })
end
for _, key in ipairs({ "<A-Down>", "<C-S-Down>" }) do
    map("n", key, "<cmd>m .+1<cr>==",             { desc = "Move line down" })
    map("i", key, "<esc><cmd>m .+1<cr>==gi",      { desc = "Move line down" })
    map("x", key, ":m '>+1<cr>gv=gv",             { desc = "Move selection down" })
    map("s", key, keep_select(":m '>+1<cr>gv=gv"), { desc = "Move selection down" })
end

-- Splits
map("n", "<leader>v", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>h", "<cmd>split<cr>",  { desc = "Horizontal split" })

-- ------------------------------------------------------------------
-- Word-wise movement (VSCode style)
-- ------------------------------------------------------------------
-- Like w/b, but never crosses a line boundary: past the last word the
-- cursor stops at end of line, before the first word at column 1.
--
-- Selecting by word (<C-S-Left/Right>) is left to Vim: with keymodel=startsel
-- it strips the Shift, starts the selection and reuses these same mappings.
local function word_move(dir)
    local pos    = vim.api.nvim_win_get_cursor(0)
    local len    = #vim.api.nvim_get_current_line()
    local insert = vim.api.nvim_get_mode().mode:find("^i") ~= nil

    vim.cmd("normal! " .. (dir == "right" and "w" or "b"))

    -- The motion wrapped onto another line: clamp back to this one.
    if vim.api.nvim_win_get_cursor(0)[1] ~= pos[1] then
        local col = 0
        if dir == "right" then
            -- insert mode may sit one past the last character
            col = insert and len or math.max(len - 1, 0)
        end
        vim.api.nvim_win_set_cursor(0, { pos[1], col })
    end
end

map({ "n", "x", "i" }, "<C-Left>",  function() word_move("left")  end, { desc = "Word left" })
map({ "n", "x", "i" }, "<C-Right>", function() word_move("right") end, { desc = "Word right" })

-- ------------------------------------------------------------------
-- Find / Replace (VSCode style)
-- ------------------------------------------------------------------
-- <C-f> and <C-h> open the command line seeded with the selection, with
-- the cursor where you'd start typing; <cr> runs it. <F3> / <S-F3> walk
-- the matches, <Esc> clears the highlighting.
--
-- Note: many terminals send ^H for Ctrl+Backspace, so the insert-mode
-- half of <C-h> shadows it. Drop "i" from that map if you use it.

-- Select mode has its own mode letters; getregion() only knows Visual's.
local visual_kind = {
    v = "v", V = "V", ["\22"] = "\22", -- Visual, line, block
    s = "v", S = "V", ["\19"] = "\22", -- the Select equivalents
}

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

-- Escape for use as a \V ("very nomagic") pattern, where only the
-- backslash and the / delimiter still mean anything.
local function pattern_of(text)
    return "\\V" .. vim.fn.escape(text, "\\/")
end

-- feed() translates key notation; feed_raw() doesn't, so a "<" in the
-- selected text isn't read as the start of a key name.
local function feed(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
end
local function feed_raw(text)
    vim.api.nvim_feedkeys(text, "n", false)
end

local function find()
    local word = selected_word(selected_lines())
    feed("<Esc>/") -- <Esc> first: search the file, not the selection
    if word then
        feed_raw(pattern_of(word))
    end
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
        feed_raw(":'<,'>s///g")
        feed("<Left><Left><Left>")
    else
        feed_raw(":%s///g")
        feed("<Left><Left><Left>")
    end
end

map({ "n", "i", "x", "s" }, "<C-f>", find,    { desc = "Find" })
map({ "n", "i", "x", "s" }, "<C-h>", replace, { desc = "Find and replace" })

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
				require('onedark').setup {
					style = 'darker',
					highlights = {
						["@punctuation.bracket"] = { fg = "#e06c75" },
						["@punctuation.delimiter"] = { fg = "#e06c75" },
					}
				}
				require('onedark').load()
			end
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
                    "python", "go", "java", "json",
                })
            end,
        },
        {
            "windwp/nvim-autopairs",
            event = "InsertEnter",
            opts = {},
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
                -- Nvim disables LSP file watching on Linux, so pyright never
                -- hears about .py files created after it started.
                vim.lsp.config("pyright", {
                    capabilities = {
                        workspace = {
                            didChangeWatchedFiles = { dynamicRegistration = true },
                        },
                    },
                })

                vim.lsp.enable("pyright")
                vim.lsp.enable("clangd")
                vim.lsp.enable("neocmake")
            end,
        },
        {
            "saghen/blink.cmp",
            version = "1.*",
            dependencies = { "rafamadriz/friendly-snippets" },
            opts = {
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
    },
    checker = { enabled = true },
})
