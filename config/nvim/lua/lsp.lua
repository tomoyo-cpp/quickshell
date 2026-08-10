-- Language servers.
--
-- Neovim 0.12 resolves a server definition from `lsp/<name>.lua` anywhere on
-- the runtimepath, and nvim-lspconfig exists purely to ship those files. So
-- this only carries the places where the defaults are wrong for this machine,
-- plus the enable list.
--
-- Every binary below comes from /etc/nixos/configuration.nix. If a server does
-- not start, `:checkhealth vim.lsp` will say which one, and the fix is a
-- package in systemPackages — never something in this directory.

-- Advertise what blink.cmp can actually do (snippets, resolve support), for
-- every server rather than one at a time.
vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			workspace = { checkThirdParty = false },
			-- `vim` is a global here, not an undefined variable — without this
			-- editing this very config is a wall of warnings.
			diagnostics = { globals = { "vim" } },
			telemetry = { enable = false },
		},
	},
})

vim.lsp.config("nil_ls", {
	settings = {
		["nil"] = {
			formatting = { command = { "nixfmt" } },
		},
	},
})

vim.lsp.config("qmlls", {
	-- -E makes qmlls read QML_IMPORT_PATH. Worth knowing before trusting its
	-- diagnostics on ~/.config/quickshell: qmlls resolves types from a build
	-- directory that a hand-written shell does not have, so Quickshell's own
	-- types (PanelWindow, Singleton, the services) will be reported as
	-- unknown. Completion and syntax still work; the import errors are noise.
	cmd = { "qmlls", "-E" },
})

vim.lsp.enable({
	"lua_ls", -- lua-language-server
	"nil_ls", -- nil
	"qmlls", -- qt6.qtdeclarative
	"bashls", -- bash-language-server (runs shellcheck itself)
	"basedpyright", -- basedpyright
	"jsonls", -- vscode-langservers-extracted
})

-- ── Diagnostics ─────────────────────────────────────────────────────────
vim.diagnostic.config({
	severity_sort = true,
	float = { border = "rounded", source = true },
	underline = { severity = vim.diagnostic.severity.ERROR },
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
	},
	-- Inline, but only for the line the cursor is on: full virtual text turns
	-- a file with a few warnings into an unreadable mess at this width.
	virtual_lines = { current_line = true },
})

-- ── Per-buffer bindings ─────────────────────────────────────────────────
-- Set on attach so they only exist where a server is running. Neovim 0.11+
-- already binds grn (rename), gra (code action), grr (references), gri
-- (implementation), K (hover) and gO (symbols); these are the gaps.
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
	callback = function(ev)
		local function map(lhs, rhs, desc)
			vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
		end

		map("gd", vim.lsp.buf.definition, "Go to definition")
		map("gD", vim.lsp.buf.declaration, "Go to declaration")
		map("gy", vim.lsp.buf.type_definition, "Go to type definition")
		map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
		map("<leader>cr", vim.lsp.buf.rename, "Rename")
		map("<leader>ca", vim.lsp.buf.code_action, "Code action")

		-- Inlay hints, where the server offers them. Off by default: they are
		-- useful when reading and in the way when writing.
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client:supports_method("textDocument/inlayHint") then
			map("<leader>uh", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
			end, "Toggle inlay hints")
		end
	end,
})
