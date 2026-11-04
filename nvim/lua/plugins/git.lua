-- Match Zed's One Dark git gutter colors in Neovim's sign column.
-- Zed theme keys: version_control.added / .modified / .deleted.
local colors = {
  add = "#27a657",
  change = "#d3b020",
  delete = "#e06c76",
}

local function apply()
  local hl = vim.api.nvim_set_hl
  hl(0, "GitSignsAdd", { fg = colors.add })
  hl(0, "GitSignsChange", { fg = colors.change })
  hl(0, "GitSignsDelete", { fg = colors.delete })
  hl(0, "GitSignsAddNr", { fg = colors.add })
  hl(0, "GitSignsChangeNr", { fg = colors.change })
  hl(0, "GitSignsDeleteNr", { fg = colors.delete })
  hl(0, "GitSignsStagedAdd", { fg = colors.add })
  hl(0, "GitSignsStagedChange", { fg = colors.change })
  hl(0, "GitSignsStagedDelete", { fg = colors.delete })
end

return {
  {
    "lewis6991/gitsigns.nvim",
    -- Zed's bar is wider than gitsigns' default "▎" (one quarter block).
    -- "▌" is half a cell and reads closest to Zed's gutter.
    opts = {
      -- Zed marks a replaced block as one "modified" hunk. vim.diff's
      -- linematch splits it into one changed line plus trailing additions,
      -- which paints most of the block green. Disabling it keeps the whole
      -- replacement yellow, like Zed.
      diff_opts = { linematch = 0 },
      signs = {
        add = { text = "▌" },
        change = { text = "▌" },
        changedelete = { text = "▌" },
        untracked = { text = "▌" },
      },
      signs_staged = {
        add = { text = "▌" },
        change = { text = "▌" },
        changedelete = { text = "▌" },
      },
    },
    config = function(_, opts)
      require("gitsigns").setup(opts)
      apply()

      -- gitsigns splits a change hunk into one "change" line plus "add" lines
      -- for the surplus, so a replaced block renders mostly green. Zed paints
      -- the whole replaced range as modified; promote those surplus signs.
      local hunks = require("gitsigns.hunks")
      if not hunks.__zed_change_block then
        local calc_signs = hunks.calc_signs
        hunks.calc_signs = function(prev_hunk, hunk, next_hunk, min_lnum, max_lnum, untracked)
          local vend = hunk.vend or (hunk.added.start + hunk.added.count - 1)
          local signs = calc_signs(prev_hunk, hunk, next_hunk, min_lnum, max_lnum, untracked)
          if hunk.type == "change" and hunk.added.count > hunk.removed.count then
            for _, sign in ipairs(signs) do
              if sign.type == "add" and sign.lnum >= hunk.added.start and sign.lnum <= vend then
                sign.type = "change"
                sign.count = nil
              end
            end
          end
          return signs
        end
        hunks.__zed_change_block = true
      end

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("ZedGitGutter", { clear = true }),
        callback = apply,
      })
    end,
  },
}
