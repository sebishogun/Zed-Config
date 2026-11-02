-- Right-hand scrollbar with Zed-style git marks.
-- v2: the "zed" preset uses the same three-lane layout (git, thumb, diagnostics)
-- and the gitsigns provider paints hunks with the GitSigns colors from git.lua.
return {
  {
    "petertriho/nvim-scrollbar",
    branch = "refactor/v2", -- v2 lands on main 2026-11-16; drop the pin after that
    event = "VeryLazy",
    dependencies = { "lewis6991/gitsigns.nvim" },
    opts = {
      providers = {
        gitsigns = true,
      },
      scrollbar = {
        preset = "zed",
        visibility = "all",
        autohide = false,
      },
    },
  },
}
