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
        -- Owned below so a replaced block is one modified mark, like Zed.
        gitsigns = false,
        handle = true,
        search = false, -- needs hlslens
      },
      handle = {
        text = "  ",
        blend = 30,
        highlight = "CursorColumn",
      },
      marks = {
        Cursor = { text = "• ", priority = 0, highlight = "CursorLineNr" },
        GitAdd = { text = "██", priority = 7, highlight = "GitSignsAdd" },
        GitChange = { text = "██", priority = 7, highlight = "GitSignsChange" },
        GitDelete = { text = "▁▁", priority = 7, highlight = "GitSignsDelete" },
        Error = { text = { "--", "==" }, priority = 2, highlight = "DiagnosticVirtualTextError" },
        Warn = { text = { "--", "==" }, priority = 3, highlight = "DiagnosticVirtualTextWarn" },
        Info = { text = { "--", "==" }, priority = 4, highlight = "DiagnosticVirtualTextInfo" },
        Hint = { text = { "--", "==" }, priority = 5, highlight = "DiagnosticVirtualTextHint" },
      },
    },
    config = function(_, opts)
      require("scrollbar").setup(opts)

      -- nvim-scrollbar's v1 gitsigns handler mirrors gitsigns' sign split:
      -- the overlap is GitChange and the surplus lines are GitAdd. Zed paints
      -- the whole replaced range as modified, so build the marks here.
      local function gitsigns_marks(bufnr, config)
        local hunks = require("gitsigns").get_hunks(bufnr) or {}
        local marks = {}
        for _, hunk in ipairs(hunks) do
          if hunk.type == "add" then
            for line = hunk.added.start, hunk.added.start + hunk.added.count - 1 do
              marks[#marks + 1] = {
                line = line - 1,
                text = config.marks.GitAdd.text,
                type = "GitAdd",
                level = 1,
              }
            end
          elseif hunk.type == "change" then
            for line = hunk.added.start, hunk.added.start + hunk.added.count - 1 do
              marks[#marks + 1] = {
                line = line - 1,
                text = config.marks.GitChange.text,
                type = "GitChange",
                level = 1,
              }
            end
          elseif hunk.type == "delete" then
            marks[#marks + 1] = {
              line = hunk.added.start - 1,
              text = config.marks.GitDelete.text,
              type = "GitDelete",
              level = 1,
            }
          end
        end
        return marks
      end

      local function update()
        local config = require("scrollbar.config").get()
        local utils = require("scrollbar.utils")
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            local marks = utils.get_scrollbar_marks(bufnr)
            marks.gitsigns = gitsigns_marks(bufnr, config)
            utils.set_scrollbar_marks(bufnr, marks)
          end
        end
        require("scrollbar").throttled_render()
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "GitSignsUpdate",
        group = vim.api.nvim_create_augroup("ZedScrollbarGit", { clear = true }),
        callback = update,
      })

      update()
    end,
  },
}
