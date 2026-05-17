return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Prevent lspconfig from setting up rust_analyzer (rustaceanvim handles it)
      setup = {
        rust_analyzer = function()
          return true -- returning true prevents lspconfig from setting up this server
        end,
      },
      servers = {
        gopls = { settings = { gopls = { staticcheck = true, gofumpt = true, usePlaceholders = true, analyses = { unusedparams = true, shadow = true, fieldalignment = true, nilness = true, unusedwrite = true, useany = true }, hints = { assignVariableTypes = true, compositeLiteralFields = true, constantValues = true, functionTypeParameters = true, parameterNames = true, rangeVariableTypes = true } } } },
        -- Explicitly disable rust_analyzer - rustaceanvim handles it (see rust.lua)
        rust_analyzer = false,
        zls = {},
        clangd = {},
        pyright = {},
        lua_ls = {},
        ts_ls = {},  -- renamed from tsserver in newer lspconfig
        eslint = {},
        html = {},
        cssls = {},
        tailwindcss = {},
        jsonls = {},
        yamlls = {},
        bashls = {},
        dockerls = {},
        marksman = {},
        sqlls = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      -- On macOS, LSPs/formatters are installed via brew (scripts/brew-install-tools.sh)
      -- so Mason doesn't need to download anything. On Linux, Mason handles installs.
      ensure_installed = vim.fn.has("mac") == 1 and {} or {
        "gopls", "rust-analyzer", "zls", "clangd", "pyright",
        "lua-language-server", "typescript-language-server", "eslint-lsp",
        "html-lsp", "css-lsp", "tailwindcss-language-server", "json-lsp",
        "yaml-language-server", "bash-language-server", "dockerfile-language-server",
        "marksman", "sqlls", "stylua", "shfmt", "black", "prettier",
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    enabled = vim.fn.has("mac") == 0,
  },
}
