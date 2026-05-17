-- Dressing.nvim: Better UI for code actions, input, select
return {
  "stevearc/dressing.nvim",
  lazy = false,
  opts = {
    input = {
      enabled = true,
      default_prompt = "Input:",
      prompt_align = "left",
      insert_only = true,
      start_in_insert = true,
      border = "rounded",
      relative = "cursor",
      prefer_width = 40,
      max_width = { 140, 0.9 },
      min_width = { 20, 0.2 },
      win_options = { winblend = 0, wrap = true },
    },
    select = {
      enabled = true,
      backend = { "telescope", "builtin" },
      trim_prompt = true,
      telescope = {
        layout_strategy = "vertical",
        layout_config = { vertical = { prompt_position = "top", mirror = true, preview_height = 0 }, width = 0.6, height = 0.4 },
        sorting_strategy = "ascending",
      },
      builtin = { border = "rounded", relative = "editor", win_options = { winblend = 0, wrap = true } },
    },
  },
}
