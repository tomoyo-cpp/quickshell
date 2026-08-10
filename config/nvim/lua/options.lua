-- Editor settings. Anything here is a plain Neovim option; no plugin needed.

local o = vim.opt

-- ── Look ────────────────────────────────────────────────────────────────
o.number = true
o.relativenumber = true -- jump distances for {count}j / {count}k
o.signcolumn = "yes" -- always on, so the text does not shift when a sign appears
o.cursorline = true
o.termguicolors = true
o.showmode = false -- lualine already says it
o.scrolloff = 8 -- keep context above and below the cursor
o.sidescrolloff = 8
o.wrap = false
o.fillchars = { eob = " " } -- no ~ on the empty lines past the end of a buffer

-- ── Indentation ─────────────────────────────────────────────────────────
-- Four-wide tabs, matching the QML and shell in ~/.config/quickshell.
-- Treesitter supplies the real indent rules per language on top of this.
o.tabstop = 4
o.shiftwidth = 4
o.expandtab = true
o.smartindent = true

-- ── Search ──────────────────────────────────────────────────────────────
o.ignorecase = true
o.smartcase = true -- ...unless the pattern has a capital in it
o.hlsearch = true
o.incsearch = true

-- ── Files ───────────────────────────────────────────────────────────────
o.undofile = true -- undo survives closing the file
o.swapfile = false
o.backup = false
o.updatetime = 250 -- also how fast gitsigns blame and hover fire
o.timeoutlen = 400

-- ── Windows ─────────────────────────────────────────────────────────────
o.splitright = true
o.splitbelow = true

-- ── Completion ──────────────────────────────────────────────────────────
o.completeopt = { "menu", "menuone", "noselect" }
o.pumheight = 10

-- Share the system clipboard. Scheduled because reading the Wayland selection
-- at startup costs a round trip to the compositor, and doing it before the UI
-- is up delays the first frame.
vim.schedule(function()
	o.clipboard = "unnamedplus"
end)

-- ── Diff ────────────────────────────────────────────────────────────────
o.diffopt:append("linematch:60") -- line up changes inside a hunk, not just the hunk

-- Flash what was just yanked, so it is obvious what went to the clipboard.
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("yank-highlight", { clear = true }),
	callback = function()
		vim.hl.on_yank({ timeout = 150 })
	end,
})
