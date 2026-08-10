-- Global bindings. Leader is Space.
--
-- LSP bindings are not here — they are set per buffer in lsp.lua, so they only
-- exist where a server is actually attached.
--
-- Neovim 0.11+ already provides a lot of this: gc / gcc comment, grn rename,
-- gra code action, grr references, gri implementation, K hover, gO symbols.
-- Nothing below re-binds those.

local map = vim.keymap.set

-- ── Basics ──────────────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })

-- Keep the cursor centred when paging and when jumping between matches.
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Move the selected lines up and down, reindenting as they go.
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Reindent without losing the selection.
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Paste over a selection without the clipboard picking up what was replaced.
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- ── Windows ─────────────────────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- ── Buffers ─────────────────────────────────────────────────────────────
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- ── Terminal ────────────────────────────────────────────────────────────
-- Esc alone belongs to the shell; double it to get back to normal mode.
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
