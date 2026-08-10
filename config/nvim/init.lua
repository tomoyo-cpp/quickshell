-- Neovim, for NixOS + niri.
--
-- Two rules this config is built around:
--
--  1. Nothing here installs a binary. Mason cannot work on NixOS — it fetches
--     dynamically linked releases that will not run against the Nix store — so
--     every language server, formatter and linter comes from
--     /etc/nixos/configuration.nix instead. Supporting a new language means
--     adding a package there, then a line in lua/lsp.lua. If a tool is
--     missing, that is where to look; nothing in this directory can fix it.
--
--  2. Lean on purpose. Twelve plugins. Neovim 0.12 already ships LSP config
--     (vim.lsp.config), commenting (gc), and even a plugin manager (vim.pack),
--     so this only adds what it does not already have.
--
-- Layout: options.lua (settings), keymaps.lua (bindings), plugins.lua (the
-- twelve specs), lsp.lua (servers, diagnostics, per-buffer bindings).

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("options")

-- lazy.nvim, bootstrapped on first launch.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
	change_detection = { notify = false },
	-- Neovim is not the package manager on this machine.
	rocks = { enabled = false },
	ui = { border = "rounded" },
})

require("keymaps")
require("lsp")
