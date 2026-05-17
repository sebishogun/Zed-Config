-- OpenFOAM support for LazyVim
return {
  -- Add foam filetype detection
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.filetype.add({
        pattern = {
          [".*Dict"] = "foam",
          [".*Properties"] = "foam",
          ["fvSchemes"] = "foam",
          ["fvSolution"] = "foam",
          ["controlDict"] = "foam",
          ["blockMeshDict"] = "foam",
          [".*/0/.*"] = "foam",
          [".*/0%.orig/.*"] = "foam",
        },
      })
    end,
  },

  -- Add foam icon
  {
    "nvim-tree/nvim-web-devicons",
    opts = {
      override_by_extension = {
        foam = { icon = "", color = "#1e88e5", name = "OpenFOAM" },
      },
    },
  },

  -- Configure foam_ls
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        foam_ls = {},
      },
      setup = {
        foam_ls = function()
          local lspconfig = require("lspconfig")
          local configs = require("lspconfig.configs")

          if not configs.foam_ls then
            configs.foam_ls = {
              default_config = {
                cmd = { "/home/sebishogun/.local/bin/foam-ls", "--stdio" },
                filetypes = { "foam" },
                root_dir = lspconfig.util.root_pattern("system", "constant", "0"),
                single_file_support = true,
              },
            }
          end

          lspconfig.foam_ls.setup({})
          return true -- tell LazyVim we handled it
        end,
      },
    },
  },
}
