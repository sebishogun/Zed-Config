-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local initial_cwd = vim.g.nvim_initial_cwd or (vim.uv or vim.loop).cwd() or vim.fn.getcwd()

-- Resolve the directory of the active buffer (or hovered Neo-tree folder/file)
local function resolve_local_dir()
  if vim.bo.filetype == "neo-tree" then
    local ok, manager = pcall(require, "neo-tree.sources.manager")
    if ok then
      local state = manager.get_state("filesystem")
      local node = state and state.tree and state.tree:get_node()
      if node then
        local path = node:get_id()
        if path and path ~= "" then
          if node.type ~= "directory" and vim.fn.isdirectory(path) == 0 then
            path = vim.fn.fnamemodify(path, ":h")
          end
          if vim.fn.isdirectory(path) == 1 then
            return path
          end
        end
      end
      if state and state.path and vim.fn.isdirectory(state.path) == 1 then
        return state.path
      end
    end
  end

  if vim.bo.buftype == "" then
    local buf_dir = vim.fn.expand("%:p:h")
    if buf_dir ~= "" and vim.fn.isdirectory(buf_dir) == 1 then
      return buf_dir
    end
  end

  return vim.fn.getcwd(0)
end

-- Hide any currently visible snacks terminal except the one matching (target_cwd, target_count)
local function hide_other_terminals(target_cwd, target_count)
  for _, term in pairs(Snacks.terminal.list()) do
    if term:valid() then
      local info = vim.b[term.buf] and vim.b[term.buf].snacks_terminal
      if not info or info.cwd ~= target_cwd or info.id ~= target_count then
        term:hide()
      end
    end
  end
end

-- Ctrl + / : Toggle Local Terminal (scoped to current buffer's / Neo-tree's directory)
local function toggle_local_terminal()
  -- If already focused inside a terminal window, toggle it closed
  if vim.bo.buftype == "terminal" or vim.bo.filetype == "snacks_terminal" then
    for _, term in pairs(Snacks.terminal.list()) do
      if term.buf == vim.api.nvim_get_current_buf() and term:valid() then
        term:hide()
        return
      end
    end
  end

  local dir = resolve_local_dir()
  hide_other_terminals(dir, 1)
  Snacks.terminal.toggle(nil, { cwd = dir, count = 1 })
end

-- Ctrl + Shift + / : Toggle Global Terminal (scoped to initial directory where Neovim opened)
local function toggle_global_terminal()
  local global_dir = vim.g.nvim_initial_cwd or initial_cwd
  if vim.bo.buftype == "terminal" or vim.bo.filetype == "snacks_terminal" then
    local cur_buf = vim.api.nvim_get_current_buf()
    local info = vim.b[cur_buf] and vim.b[cur_buf].snacks_terminal
    if info and info.cwd == global_dir and info.id == 99 then
      for _, term in pairs(Snacks.terminal.list()) do
        if term.buf == cur_buf and term:valid() then
          term:hide()
          return
        end
      end
    end
  end

  hide_other_terminals(global_dir, 99)
  Snacks.terminal.toggle(nil, { cwd = global_dir, count = 99 })
end

-- Local terminal (current file / explorer directory): Ctrl + /
vim.keymap.set({ "n", "t" }, "<c-/>", toggle_local_terminal, { desc = "Toggle Terminal (Local Dir)" })
vim.keymap.set({ "n", "t" }, "<c-_>", toggle_local_terminal, { desc = "which_key_ignore" })

-- Global terminal (initial Neovim launch directory): Ctrl + Shift + /
-- Mapped across all CSI-u / legacy key representations of Ctrl+Shift+/ (and <leader>fT)
vim.keymap.set({ "n", "t" }, "<c-s-/>", toggle_global_terminal, { desc = "Toggle Terminal (Global Initial Dir)" })
vim.keymap.set({ "n", "t" }, "<c-?>", toggle_global_terminal, { desc = "Toggle Terminal (Global Initial Dir)" })
vim.keymap.set({ "n", "t" }, "<c-s-?>", toggle_global_terminal, { desc = "which_key_ignore" })
vim.keymap.set("n", "<leader>fT", toggle_global_terminal, { desc = "Terminal (Global Initial Dir)" })
vim.keymap.set("n", "<leader>ft", toggle_local_terminal, { desc = "Terminal (Local Buffer Dir)" })

-- In visual mode, Shift+Left/Right should outdent/indent the selected block.
vim.keymap.set("v", "<S-Left>", "<gv", { noremap = true, silent = true, desc = "Outdent selection" })
vim.keymap.set("v", "<S-Right>", ">gv", { noremap = true, silent = true, desc = "Indent selection" })

