return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    ft = { "markdown", "Avante", "codecompanion" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      file_types = { "markdown", "Avante", "codecompanion" },
      heading = {
        sign = false,
        position = "inline",
        icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " },
        width = "block",
        left_pad = 0,
        right_pad = 4,
        min_width = 80,
      },
      code = {
        sign = false,
        style = "full",
        width = "block",
        min_width = 80,
        right_pad = 4,
        border = "thick",
      },
      bullet = {
        icons = { "●", "○", "◆", "◇" },
      },
      checkbox = {
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰱒 " },
      },
      pipe_table = {
        style = "full",
        cell = "padded",
      },
      link = {
        enabled = true,
        image = "󰥶 ",
        hyperlink = "󰌹 ",
      },
    },
  },
}
