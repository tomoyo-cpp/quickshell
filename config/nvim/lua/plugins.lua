-- Eleven plugins. Each one earns its place; nothing here duplicates something
-- Neovim 0.12 already does.

return {
	-- ── Colours ─────────────────────────────────────────────────────────
	-- Mocha with a red accent and a transparent background, matching the
	-- quickshell bar and kitty at 0.7 opacity. To follow a theme change in
	-- the bar, edit `accent` below — the palette names are the same ones the
	-- Appearance tab uses (red, mauve, blue, teal, peach, …).
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000, -- loaded before anything that reads highlight groups
		config = function()
			local accent = "red"
			require("catppuccin").setup({
				flavour = "mocha",
				transparent_background = true,
				integrations = {
					blink_cmp = true,
					gitsigns = true,
					treesitter = true,
					native_lsp = { enabled = true },
				},
				custom_highlights = function(c)
					return {
						CursorLineNr = { fg = c[accent], style = { "bold" } },
						IncSearch = { bg = c[accent], fg = c.base },
						MatchParen = { fg = c[accent], style = { "bold" } },
						-- Transparency leaves floats sitting on the wallpaper,
						-- which is unreadable. Give them their own surface.
						NormalFloat = { bg = c.mantle },
						FloatBorder = { fg = c.surface1, bg = c.mantle },
					}
				end,
			})
			vim.cmd.colorscheme("catppuccin")
		end,
	},

	-- ── Statusline ──────────────────────────────────────────────────────
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		event = "VeryLazy",
		opts = {
			options = {
				theme = "catppuccin",
				globalstatus = true, -- one line for all splits
				section_separators = "",
				component_separators = "|",
			},
			sections = {
				lualine_c = { { "filename", path = 1 } },
				lualine_x = { "diagnostics", "filetype" },
			},
		},
	},

	-- ── Syntax ──────────────────────────────────────────────────────────
	-- The `main` branch is a full rewrite: no configs.setup(), no highlight
	-- module, and no lazy-loading. Highlighting is started by hand per
	-- buffer, which is what the autocmd below does.
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").setup()

			require("nvim-treesitter").install({
				"bash",
				"c",
				"css",
				"diff",
				"fish",
				"git_config",
				"gitcommit",
				"html",
				"json", -- also serves jsonc; there is no separate parser
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"nix",
				"python",
				"qmljs", -- QML
				"query",
				"regex",
				"toml",
				"vim",
				"vimdoc",
				"yaml",
			})

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
				callback = function(ev)
					local lang = vim.treesitter.language.get_lang(ev.match)
					if not lang then
						return
					end
					-- pcall: a parser still compiling on first launch, or one
					-- that simply is not installed, should not throw on every
					-- file opened.
					if pcall(vim.treesitter.start, ev.buf, lang) then
						vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})
		end,
	},

	-- ── Finding things ──────────────────────────────────────────────────
	-- fzf-lua rather than telescope: it drives the fzf binary already in
	-- systemPackages, so there is no native extension to compile. On a
	-- machine with no C toolchain by default, that mattered.
	{
		"ibhagwan/fzf-lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		cmd = "FzfLua",
		keys = {
			{ "<leader><space>", "<cmd>FzfLua files<CR>", desc = "Find files" },
			{ "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find files" },
			{ "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Grep" },
			{ "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Buffers" },
			{ "<leader>fr", "<cmd>FzfLua oldfiles<CR>", desc = "Recent files" },
			{ "<leader>fh", "<cmd>FzfLua helptags<CR>", desc = "Help" },
			{ "<leader>fk", "<cmd>FzfLua keymaps<CR>", desc = "Keymaps" },
			{ "<leader>fd", "<cmd>FzfLua diagnostics_document<CR>", desc = "Diagnostics" },
			{ "<leader>fs", "<cmd>FzfLua lsp_document_symbols<CR>", desc = "Symbols" },
			{ "<leader>fw", "<cmd>FzfLua grep_cword<CR>", desc = "Grep word under cursor" },
		},
		opts = {
			"default-title",
			winopts = { height = 0.85, width = 0.85, preview = { layout = "vertical" } },
		},
	},

	-- ── Files ───────────────────────────────────────────────────────────
	-- A directory is just a buffer: rename, delete and create by editing the
	-- lines and writing. Replaces a file-tree sidebar entirely.
	{
		"stevearc/oil.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		lazy = false,
		keys = {
			{ "-", "<cmd>Oil<CR>", desc = "Open parent directory" },
		},
		opts = {
			view_options = { show_hidden = true },
			keymaps = { ["<Esc>"] = "actions.close" },
		},
	},

	-- ── Git ─────────────────────────────────────────────────────────────
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			current_line_blame_opts = { delay = 300 },
			on_attach = function(buf)
				local gs = require("gitsigns")
				local function map(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
				end
				map("n", "]h", function()
					gs.nav_hunk("next")
				end, "Next hunk")
				map("n", "[h", function()
					gs.nav_hunk("prev")
				end, "Previous hunk")
				map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
				map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
				map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
				map("n", "<leader>gb", gs.blame_line, "Blame line")
				map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle inline blame")
				map("n", "<leader>gd", gs.diffthis, "Diff this file")
			end,
		},
	},

	-- ── LSP ─────────────────────────────────────────────────────────────
	-- Only supplies the server definitions. Neovim 0.12 does the wiring
	-- itself through vim.lsp.config / vim.lsp.enable — see lua/lsp.lua.
	{
		"neovim/nvim-lspconfig",
		lazy = false,
	},

	-- ── Completion ──────────────────────────────────────────────────────
	{
		"saghen/blink.cmp",
		version = "1.*",
		lazy = false, -- so lsp.lua can read its capabilities at startup
		opts = {
			keymap = { preset = "default" }, -- C-space open, C-n/C-p move, C-y accept
			appearance = { nerd_font_variant = "mono" },
			completion = {
				documentation = { auto_show = true, auto_show_delay_ms = 250 },
				ghost_text = { enabled = true },
			},
			sources = { default = { "lsp", "path", "snippets", "buffer" } },
			signature = { enabled = true },
			-- The Rust matcher ships as a prebuilt, dynamically linked binary
			-- that will not run against the Nix store. The Lua implementation
			-- needs neither a download nor a compiler.
			fuzzy = { implementation = "lua" },
		},
	},

	-- ── Formatting ──────────────────────────────────────────────────────
	-- Every formatter here comes from configuration.nix.
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		keys = {
			{
				"<leader>cf",
				function()
					require("conform").format({ async = true, lsp_format = "fallback" })
				end,
				mode = { "n", "v" },
				desc = "Format buffer",
			},
		},
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				nix = { "nixfmt" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				python = { "ruff_organize_imports", "ruff_format" },
				qml = { "qmlformat" },
				json = { "jq" },
				jsonc = { "jq" },
			},
			formatters = {
				-- Not one of conform's built-ins. qmlformat takes a path, not
				-- stdin, and defaults to printing the result — so it needs -i
				-- to rewrite the file conform hands it. Without that flag the
				-- run succeeds and silently changes nothing.
				qmlformat = {
					command = "qmlformat",
					args = { "-i", "$FILENAME" },
					stdin = false,
				},
				shfmt = { prepend_args = { "-i", "4", "-ci" } },
			},
			format_on_save = function(bufnr)
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
				return { timeout_ms = 2000, lsp_format = "fallback" }
			end,
		},
		init = function()
			-- Make gq use conform too.
			vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

			vim.api.nvim_create_user_command("FormatToggle", function(args)
				if args.bang then
					vim.b.disable_autoformat = not vim.b.disable_autoformat
				else
					vim.g.disable_autoformat = not vim.g.disable_autoformat
				end
				vim.notify(
					("Format on save %s%s"):format(
						(args.bang and vim.b.disable_autoformat or vim.g.disable_autoformat) and "off" or "on",
						args.bang and " (this buffer)" or ""
					)
				)
			end, { bang = true, desc = "Toggle format on save (! for this buffer only)" })
		end,
	},

	-- ── Pairs ───────────────────────────────────────────────────────────
	{
		"echasnovski/mini.pairs",
		event = "InsertEnter",
		opts = {},
	},
}
