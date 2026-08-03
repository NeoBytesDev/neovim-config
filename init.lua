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
vim.opt.keymodel = "startsel,stopsel" -- Shift+Home/End/PgUp/PgDn selects
vim.opt.clipboard = "unnamedplus"     -- share clipboard with the system
vim.opt.undofile = true               -- persistent undo across sessions
vim.opt.ignorecase = true             -- case-insensitive search...
vim.opt.smartcase = true              -- ...unless the query has uppercase
vim.opt.swapfile = false              -- no swap files

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
        if not skip_ts_indent[vim.bo[ev.buf].filetype] then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
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
local map = vim.keymap.set

-- Move by word (VSCode style)
map({ "n", "v" }, "<C-Left>",  "b", { desc = "Word left" })
map({ "n", "v" }, "<C-Right>", "w", { desc = "Word right" })
map("i", "<C-Left>",  "<cmd>normal! b<cr>", { desc = "Word left" })
map("i", "<C-Right>", "<cmd>normal! w<cr>", { desc = "Word right" })

-- Save file (and return to normal mode)
map("n", "<C-s>", "<cmd>w<cr>",        { desc = "Save file" })
map("i", "<C-s>", "<esc><cmd>w<cr>",   { desc = "Save file" })
map("v", "<C-s>", "<esc><cmd>w<cr>",   { desc = "Save file" })

-- Quit nvim entirely (asks about unsaved files)
map("n", "<leader>q", "<cmd>confirm qa<cr>", { desc = "Quit nvim" })

-- Indent / dedent
map("n", "<S-Tab>", "<<",    { desc = "Dedent line" })
map("i", "<S-Tab>", "<C-d>", { desc = "Dedent line" })
map("v", "<Tab>",   ">gv",   { desc = "Indent selection" })
map("v", "<S-Tab>", "<gv",   { desc = "Dedent selection" })
map("n", "<Tab>",   ">>",    { desc = "Indent line" })
map("v", "<Tab>",   ">gv",   { desc = "Indent selection" })

-- Copy / paste (system clipboard)
map("v", "<C-c>", '"+y',          { desc = "Copy selection" })
map("n", "<C-c>", '"+yy',         { desc = "Copy line" })
map({ "n", "v" }, "<C-v>", '"+p', { desc = "Paste" })
map("i", "<C-v>", "<C-r>+",       { desc = "Paste" })

-- Undo / redo
map("n", "<C-z>", "u",          { desc = "Undo" })
map("i", "<C-z>", "<C-o>u",     { desc = "Undo" })
map("n", "<C-y>", "<C-r>",      { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })

-- Toggle comment (VSCode style; <C-_> is how terminals send Ctrl+/)
map("n", "<C-_>", "gcc", { remap = true, desc = "Toggle comment" })
map("v", "<C-_>", "gc",  { remap = true, desc = "Toggle comment" })
map("n", "<C-/>", "gcc", { remap = true, desc = "Toggle comment" })
map("v", "<C-/>", "gc",  { remap = true, desc = "Toggle comment" })

-- Move line / selection up and down
map("n", "<A-Up>",     "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("n", "<A-Down>",   "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<C-S-Up>",   "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("n", "<C-S-Down>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("i", "<C-S-Up>",   "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("i", "<C-S-Down>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("v", "<C-S-Up>",   ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
map("v", "<C-S-Down>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })

-- Splits
map("n", "<leader>v", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>h", "<cmd>split<cr>",  { desc = "Horizontal split" })

-- ------------------------------------------------------------------
-- Word-wise movement (VSCode style)
-- ------------------------------------------------------------------
-- Like w/b, but never crosses a line boundary: past the last word the
-- cursor stops at end of line, before the first word at column 1.
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

-- Start a selection if there isn't one, then extend it by a word.
local function word_select(dir)
    if not vim.api.nvim_get_mode().mode:find("^[vV\22]") then
        vim.cmd("normal! v")
    end
    word_move(dir)
end

-- Same, but starting from insert mode: <Esc> lands one column left, so
-- step back right unless we were at the start of the line or already
-- past its last character.
local function word_select_i(dir)
    local col   = vim.api.nvim_win_get_cursor(0)[2]
    local len   = #vim.api.nvim_get_current_line()
    local nudge = dir == "right" and col > 0 and col < len
    vim.api.nvim_feedkeys(vim.keycode(nudge and "<Esc>lv" or "<Esc>v"), "nx", false)
    word_move(dir)
end

-- Move by word
map({ "n", "v", "i" }, "<C-Left>",  function() word_move("left")  end, { desc = "Word left" })
map({ "n", "v", "i" }, "<C-Right>", function() word_move("right") end, { desc = "Word right" })

-- Select by word
map({ "n", "v" }, "<C-S-Left>",  function() word_select("left")  end, { desc = "Select word left" })
map({ "n", "v" }, "<C-S-Right>", function() word_select("right") end, { desc = "Select word right" })
map("i", "<C-S-Left>",  function() word_select_i("left")  end, { desc = "Select word left" })
map("i", "<C-S-Right>", function() word_select_i("right") end, { desc = "Select word right" })

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
        {
            "ellisonleao/gruvbox.nvim",
            priority = 1000,
            opts = {
                contrast = "hard",
            },
            config = function(_, opts)
                require("gruvbox").setup(opts)
                vim.cmd.colorscheme("gruvbox")
            end,
        },
        {
            "nvim-lualine/lualine.nvim",
            dependencies = { "nvim-tree/nvim-web-devicons" },
            event = "VeryLazy",
            opts = {
                options = { theme = "gruvbox" },
            },
        },
        {
            "akinsho/bufferline.nvim",
            dependencies = { "nvim-tree/nvim-web-devicons" },
            event = "VeryLazy",
            opts = {
                options = {
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
                vim.lsp.config("clangd", {
                    init_options = {
                        fallbackFlags = { "-std=c++23" },
                    },
                })

                vim.lsp.enable("pyright")
                vim.lsp.enable("clangd")
				vim.lsp.enable("neocmakelsp")
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
