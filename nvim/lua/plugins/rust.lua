-- rust.lua - Rust development with rustaceanvim
-- Provides: LSP, debugging, testing, macro expansion, and more
-- NOTE: Do NOT use lspconfig for rust-analyzer - rustaceanvim handles it

return {
  {
    "mrcjkb/rustaceanvim",
    version = "^7", -- Recommended: pin to major version
    ft = { "rust" }, -- Lazy loads on Rust files
    opts = {
      server = {
        on_attach = function(client, bufnr)
          -- Keymaps are set in after/ftplugin/rust.lua
        end,
        default_settings = {
          -- rust-analyzer settings
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = {
                enable = true,
              },
            },
            -- Use Clippy for flycheck diagnostics
            -- Override deny-by-default lints that don't provide auto-fixes
            check = {
              command = "clippy",
              extraArgs = {
                "--",
                -- Downgrade approx_constant from error to warning
                -- (it's deny-by-default but has no auto-fix, which is frustrating UX)
                "-W", "clippy::approx_constant",
              },
            },
            checkOnSave = true,
            procMacro = {
              enable = true,
              ignored = {
                ["async-trait"] = { "async_trait" },
                ["napi-derive"] = { "napi" },
                ["async-recursion"] = { "async_recursion" },
              },
            },
            files = {
              excludeDirs = {
                ".direnv",
                ".git",
                ".github",
                ".gitlab",
                "bin",
                "node_modules",
                "target",
                "venv",
                ".venv",
              },
            },
          },
        },
      },
      tools = {
        -- Hover actions
        hover_actions = {
          auto_focus = false,
        },
        -- Inlay hints (Neovim 0.10+)
        inlay_hints = {
          auto = true,
        },
      },
      dap = {
        -- DAP configuration - uses codelldb from Mason
        adapter = {
          type = "server",
          port = "${port}",
          executable = {
            command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
            args = { "--port", "${port}" },
          },
        },
      },
    },
    config = function(_, opts)
      vim.g.rustaceanvim = opts
    end,
  },

  -- Ensure rust-analyzer and codelldb are installed via Mason
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "rust-analyzer", "codelldb" })
    end,
  },

  -- Add WGSL treesitter parser for shader syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "rust", "toml", "wgsl" })
    end,
  },

  -- crates.nvim for Cargo.toml management
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = {
      -- Use the built-in LSP source (nvim-cmp source is deprecated)
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
  },
}
