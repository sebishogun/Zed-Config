require("config.remote_clipboard").setup()
-- Capture the initial directory where Neovim was first launched for the Global Terminal (Ctrl+Shift+/)
vim.g.nvim_initial_cwd = (vim.uv or vim.loop).cwd() or vim.fn.getcwd()
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.number = true
vim.opt.relativenumber = true
