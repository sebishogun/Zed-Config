-- Suppress the v1/v2 migration notice if the checkout ever moves.
vim.g.scrollbar_v2_notice = false

-- Right-hand scrollbar with Zed-style git marks.
-- v2 uses one floating bar per source window, so two splits showing the same
-- buffer get independent bars. The layout is a two-cell span with no track,
-- not v2's three-lane "zed" preset.
return {
  {
    "petertriho/nvim-scrollbar",
    branch = "refactor/v2", -- v2 lands on main 2026-11-16; drop the pin after that
    event = "VeryLazy",
    dependencies = { "lewis6991/gitsigns.nvim" },
    opts = {
      providers = {
        gitsigns = true,
        cursor = true,
        diagnostic = true,
        search = false,
        marks = false,
      },
      marks = {
        Cursor = { text = { "•" }, priority = 0, highlight = "CursorLineNr" },
        GitAdd = { text = { "██" }, priority = 7, highlight = "GitSignsAdd" },
        GitChange = { text = { "██" }, priority = 7, highlight = "GitSignsChange" },
        GitDelete = { text = { "▁▁" }, priority = 7, highlight = "GitSignsDelete" },
        Error = { text = { "-" }, priority = 2, highlight = "DiagnosticVirtualTextError" },
        Warn = { text = { "-" }, priority = 3, highlight = "DiagnosticVirtualTextWarn" },
        Info = { text = { "-" }, priority = 4, highlight = "DiagnosticVirtualTextInfo" },
        Hint = { text = { "-" }, priority = 5, highlight = "DiagnosticVirtualTextHint" },
      },
      scrollbar = {
        visibility = "all",
        autohide = false,
        hide_on_cursor = false,
        placement = {
          relative = "window",
          anchor = "NE",
          row = 0,
          col = 0,
          zindex = 30,
        },
        layout = {
          direction = "auto",
          columns = {
            { "thumb", { types = { "GitAdd", "GitChange", "GitDelete" } } },
            { "thumb", { types = { "GitAdd", "GitChange", "GitDelete" } } },
          },
        },
        thumb = {
          text = " ",
          blend = 30,
          highlight = "CursorColumn",
        },
      },
    },
  },
}
