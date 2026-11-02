-- Stay on v1; silence the v2 migration notice even if the checkout moves.
vim.g.scrollbar_v2_notice = false

-- Right-hand scrollbar with Zed-style git marks (v1 layout).
-- The scrollbar thumb shows the viewport position; gitsigns hunks are painted
-- with the same GitSigns colors as the gutter. v2 is pinned out because its
-- three-lane layout is wider than the single-column bar we want.
return {
  {
    "petertriho/nvim-scrollbar",
    branch = "v1",
    event = "VeryLazy",
    dependencies = { "lewis6991/gitsigns.nvim" },
    opts = {
      show = true,
      show_in_active_only = false,
      handlers = {
        cursor = true,
        diagnostic = true,
        gitsigns = true,
        handle = true,
        search = false, -- needs hlslens
      },
      handle = {
        text = " ",
        blend = 30,
        highlight = "CursorColumn",
      },
      marks = {
        Cursor = { text = "•", priority = 0, highlight = "CursorLineNr" },
        GitAdd = { text = "▐", priority = 7, highlight = "GitSignsAdd" },
        GitChange = { text = "▐", priority = 7, highlight = "GitSignsChange" },
        GitDelete = { text = "▁", priority = 7, highlight = "GitSignsDelete" },
      },
    },
  },
}
