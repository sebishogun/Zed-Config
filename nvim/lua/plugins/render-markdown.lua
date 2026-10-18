return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    ft = { "markdown", "Avante", "codecompanion" },
    keys = {
      {
        "<leader>mr",
        "<cmd>RenderMarkdown toggle<cr>",
        ft = { "markdown", "Avante", "codecompanion" },
        desc = "Toggle Markdown Render",
      },
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      file_types = { "markdown", "Avante", "codecompanion" },
      -- Let snacks.image render LaTeX math via pdflatex + ImageMagick instead of utftex
      latex = {
        enabled = false,
      },
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

  -- Inline image, Mermaid diagram, Graphviz (dot), and LaTeX math rendering
  {
    "folke/snacks.nvim",
    init = function()
      -- Ensure Ghostty / Kitty are detected even inside tmux, herdr, or headless checks
      local term = vim.env.TERM or ""
      if vim.env.GHOSTTY_RESOURCES_DIR or term:find("ghostty", 1, true) then
        vim.env.SNACKS_GHOSTTY = "true"
      elseif vim.env.KITTY_WINDOW_ID or term:find("kitty", 1, true) then
        vim.env.SNACKS_KITTY = "true"
      end

      -- Fallback to system Chromium if Puppeteer has no cached browser and env is unset
      if not vim.env.PUPPETEER_EXECUTABLE_PATH and vim.fn.executable("chromium") == 1 then
        local cache_dir = vim.fn.expand("~/.cache/puppeteer/chrome-headless-shell")
        if vim.fn.isdirectory(cache_dir) == 0 then
          vim.env.PUPPETEER_EXECUTABLE_PATH = vim.fn.exepath("chromium")
        end
      end
    end,
    keys = {
      {
        "<leader>md",
        function()
          Snacks.image.hover()
        end,
        ft = { "markdown", "tex", "plaintex", "norg", "typst" },
        desc = "Hover / Preview Diagram or Image",
      },
    },
    opts = function(_, opts)
      opts = opts or {}
      opts.image = vim.tbl_deep_extend("force", opts.image or {}, {
        enabled = true,
        doc = {
          enabled = true,
          inline = true,
          float = true,
          max_width = 100,
          max_height = 40,
        },
        math = {
          enabled = true,
        },
        convert = {
          notify = false,
          mermaid = function()
            local theme = vim.o.background == "light" and "neutral" or "dark"
            return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-t", theme, "-s", "2" }
          end,
        },
      })

      -- Register Graphviz (```dot / ```graphviz) fenced-block transform
      vim.schedule(function()
        local ok, doc = pcall(require, "snacks.image.doc")
        if not ok or not doc or not doc.transforms then
          return
        end
        doc.transforms.dot = function(img)
          if not img.content or vim.fn.executable("dot") ~= 1 then
            return
          end
          local cache = Snacks.image.config.cache
          vim.fn.mkdir(cache, "p")
          local hash = vim.fn.sha256(img.content):sub(1, 8)
          local out = cache .. "/" .. hash .. "-graphviz.chart.png"
          if vim.fn.filereadable(out) == 0 then
            vim.system({
              "dot",
              "-Tpng",
              "-Gdpi=192",
              "-Gbgcolor=transparent",
              "-Gfontcolor=#E6E6E6",
              "-Nfontcolor=#E6E6E6",
              "-Ncolor=#79D7FF",
              "-Ecolor=#EBA055",
              "-Efontcolor=#E6E6E6",
              "-o",
              out,
            }, { stdin = img.content }):wait()
          end
          if vim.fn.filereadable(out) == 1 then
            img.src = out
            img.content = nil
          end
        end
      end)

      return opts
    end,
  },
}
