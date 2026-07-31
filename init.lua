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

-- Quit nvim entirely (asks about unsaved files)
map("n", "<leader>q", "<cmd>confirm qa<cr>", { desc = "Quit nvim" })

-- Indent / dedent
map("n", "<S-Tab>", "<<",    { desc = "Dedent line" })
map("i", "<S-Tab>", "<C-d>", { desc = "Dedent line" })
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
                hint_enable = false,                   -- no inline virtual-text hint, float only
                handler_opts = { border = "rounded" },
                floating_window_above_cur_line = true, -- hover above the line, like VSCode
                toggle_key = "<C-g>",                  -- manually show/hide while typing
                select_signature_key = "<A-n>",        -- cycle overloads
            },
        },
    },
    checker = { enabled = true },
})
