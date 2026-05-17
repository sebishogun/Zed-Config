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
        -- postgres_lsp (Mason pkg: postgres-language-server) uses libpg_query
        -- — the real PostgreSQL parser — so PG-specific syntax (DEFAULT now(),
        -- partial-index WHERE, BYTEA, BIGSERIAL, TIMESTAMPTZ) parses correctly.
        -- The old sqlls (generic sql-language-server) flagged valid PG DDL as
        -- "expected $".
        --
        -- workspace_required=false + root_dir override: lspconfig's stock
        -- postgres_lsp only attaches when a `postgres-language-server.jsonc`
        -- marker exists at the project root. We want it on every .sql buffer
        -- regardless, so relax the gate and fall back to the git root / cwd.
        postgres_lsp = {
          workspace_required = false,
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = vim.fs.root(fname, { "postgres-language-server.jsonc", ".git" })
            on_dir(root or vim.fn.getcwd())
          end,
        },
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
        "marksman", "postgres-language-server", "stylua", "shfmt", "black", "prettier",
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    enabled = vim.fn.has("mac") == 0,
  },
}
