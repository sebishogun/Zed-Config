-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Fix terminal toggle: use a fixed count so the terminal ID stays consistent
-- regardless of which buffer/root directory is active
vim.keymap.set({ "n", "t" }, "<c-/>", function()
  Snacks.terminal.toggle(nil, { count = 1 })
end, { desc = "Toggle Terminal" })
vim.keymap.set({ "n", "t" }, "<c-_>", function()
  Snacks.terminal.toggle(nil, { count = 1 })
end, { desc = "which_key_ignore" })

-- In visual mode, Shift+Left/Right should outdent/indent the selected block.
vim.keymap.set("v", "<S-Left>", "<gv", { noremap = true, silent = true, desc = "Outdent selection" })
vim.keymap.set("v", "<S-Right>", ">gv", { noremap = true, silent = true, desc = "Indent selection" })
