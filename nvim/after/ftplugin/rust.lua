-- after/ftplugin/rust.lua - Rust-specific keymaps (rustaceanvim)
-- These keymaps only apply in Rust files

-- Guard: only set keymaps if rustaceanvim is loaded
if not vim.g.rustaceanvim then
  return
end

local bufnr = vim.api.nvim_get_current_buf()

-- Helper function for buffer-local keymaps
local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
end

-- ╭──────────────────────────────────────────────────────────────╮
-- │                 Rust-specific keymaps (<leader>r)            │
-- ╰──────────────────────────────────────────────────────────────╯

-- Run/Debug (smart - at cursor position)
map("n", "<leader>rr", function() vim.cmd.RustLsp("runnables") end, "Rust: Run")
map("n", "<leader>rd", function() vim.cmd.RustLsp("debuggables") end, "Rust: Debug")
map("n", "<leader>rt", function() vim.cmd.RustLsp("testables") end, "Rust: Test")

-- Re-run last
map("n", "<leader>rR", function() vim.cmd.RustLsp({ "runnables", bang = true }) end, "Rust: Re-run last")
map("n", "<leader>rD", function() vim.cmd.RustLsp({ "debuggables", bang = true }) end, "Rust: Re-debug last")
map("n", "<leader>rT", function() vim.cmd.RustLsp({ "testables", bang = true }) end, "Rust: Re-test last")

-- Code actions and hover
map("n", "<leader>ra", function() vim.cmd.RustLsp("codeAction") end, "Rust: Code actions")
map("n", "<leader>rh", function() vim.cmd.RustLsp({ "hover", "actions" }) end, "Rust: Hover actions")

-- Diagnostics
map("n", "<leader>re", function() vim.cmd.RustLsp("explainError") end, "Rust: Explain error")
map("n", "<leader>rE", function() vim.cmd.RustLsp("renderDiagnostic") end, "Rust: Render diagnostic")

-- Macros and code insight
map("n", "<leader>rm", function() vim.cmd.RustLsp("expandMacro") end, "Rust: Expand macro")
map("n", "<leader>rp", function() vim.cmd.RustLsp("rebuildProcMacros") end, "Rust: Rebuild proc macros")

-- Navigation
map("n", "<leader>rc", function() vim.cmd.RustLsp("openCargo") end, "Rust: Open Cargo.toml")
map("n", "<leader>ro", function() vim.cmd.RustLsp("openDocs") end, "Rust: Open docs.rs")
map("n", "<leader>ru", function() vim.cmd.RustLsp("parentModule") end, "Rust: Parent module")

-- Code manipulation
map("n", "<leader>rj", function() vim.cmd.RustLsp("joinLines") end, "Rust: Join lines")
map("v", "<leader>rj", function() vim.cmd.RustLsp("joinLines") end, "Rust: Join lines")
map("n", "<leader>rs", function() vim.cmd.RustLsp("ssr") end, "Rust: Structural search/replace")

-- Crate graph and analysis
map("n", "<leader>rg", function() vim.cmd.RustLsp("crateGraph") end, "Rust: Crate graph")
map("n", "<leader>rv", function() vim.cmd.RustLsp({ "view", "hir" }) end, "Rust: View HIR")
map("n", "<leader>rV", function() vim.cmd.RustLsp({ "view", "mir" }) end, "Rust: View MIR")

-- Fly check (manual cargo check)
map("n", "<leader>rf", function() vim.cmd.RustLsp("flyCheck") end, "Rust: Fly check")

-- Override K for rust-specific hover with actions
map("n", "K", function() vim.cmd.RustLsp({ "hover", "actions" }) end, "Rust: Hover actions")
