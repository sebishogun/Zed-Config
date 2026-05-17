-- nvim-treesitter is on the `main` branch (rewrite). The old `master`-branch
-- API (`require('nvim-treesitter.configs').setup{ ensure_installed, highlight,
-- indent, textobjects }`) is gone. LazyVim's stock spec drives install +
-- highlight/indent/folds on main; we only extend it.
return {
  -- Extra parsers on top of LazyVim's defaults. `opts_extend` appends these.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "go",
        "sql",
        "java",
        "zig",
        "dockerfile",
        "make",
        "cmake",
        "css",
      },
    },
  },

  -- Textobjects (main branch). LazyVim auto-wires `move` keys only, so we
  -- replace the config to also wire `select` and keep our custom motions.
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    opts = {
      select = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        ["al"] = "@loop.outer",
        ["il"] = "@loop.inner",
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
      },
      move = {
        enable = true,
        set_jumps = true,
        keys = {
          goto_next_start = { ["]m"] = "@function.outer", ["]]"] = "@class.outer" },
          goto_next_end = { ["]M"] = "@function.outer", ["]["] = "@class.outer" },
          goto_previous_start = { ["[m"] = "@function.outer", ["[["] = "@class.outer" },
          goto_previous_end = { ["[M"] = "@function.outer", ["[]"] = "@class.outer" },
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter-textobjects").setup(opts)

      local function attach(buf)
        local ft = vim.bo[buf].filetype
        local lang = vim.treesitter.language.get_lang(ft) or ft
        -- LazyVim.treesitter.have(ft,"textobjects") is unreliable on the main
        -- branch (returns false even when the query exists). Gate on the real
        -- parser + query instead.
        local ok = pcall(vim.treesitter.get_parser, buf, lang)
        if not ok or vim.treesitter.query.get(lang, "textobjects") == nil then
          return
        end

        -- select: af/if/ac/ic/al/il/aa/ia
        for key, query in pairs(opts.select or {}) do
          vim.keymap.set({ "x", "o" }, key, function()
            require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
          end, { buffer = buf, silent = true, desc = "TS select " .. query })
        end

        -- move: ]m ]] ]M ][ [m [[ [M []
        local moves = vim.tbl_get(opts, "move", "keys") or {}
        for method, keymaps in pairs(moves) do
          for key, query in pairs(keymaps) do
            vim.keymap.set({ "n", "x", "o" }, key, function()
              require("nvim-treesitter-textobjects.move")[method](query, "textobjects")
            end, { buffer = buf, silent = true, desc = "TS move " .. query })
          end
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_ts_textobjects", { clear = true }),
        callback = function(ev)
          attach(ev.buf)
        end,
      })
      vim.tbl_map(attach, vim.api.nvim_list_bufs())
    end,
  },
}
