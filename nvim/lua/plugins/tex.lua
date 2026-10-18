return {
  {
    "lervag/vimtex",
    lazy = false, -- VimTeX recommends not lazy-loading on ft=tex for complete event handling
    init = function()
      -- Use Sioyek as the primary PDF viewer (with SyncTeX support)
      vim.g.vimtex_view_method = "sioyek"
      vim.g.vimtex_view_sioyek_exe = "sioyek"

      -- Fallback options if sioyek is not available or zathura is present
      if vim.fn.executable("sioyek") == 0 and vim.fn.executable("zathura") == 1 then
        vim.g.vimtex_view_method = "zathura"
      end

      -- Compilation settings using latexmk
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_compiler_latexmk = {
        options = {
          "-pdf",
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
        },
      }

      -- Disable quickfix automatically opening on warnings (only open on error)
      vim.g.vimtex_quickfix_open_on_warning = 0

      -- Enable conceal for math symbols if desired
      vim.g.vimtex_syntax_conceal = {
        accents = 1,
        ligatures = 1,
        cites = 1,
        fancy = 1,
        greek = 1,
        math_bounds = 1,
        math_delimiters = 1,
        math_fracs = 1,
        math_super_sub = 1,
        math_symbols = 1,
        styles = 1,
      }
    end,
  },
}
