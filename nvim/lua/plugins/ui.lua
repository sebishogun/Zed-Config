-- ui.lua - UI customizations for neo-tree, icons, and git status

return {
  -- Customize neo-tree git status symbols to be clearer
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      default_component_configs = {
        git_status = {
          symbols = {
            -- Change the untracked symbol from ? to a clearer icon
            untracked = "★", -- or use "" for a plus icon
            ignored = "◌",
            unstaged = "✗",
            staged = "✓",
            conflict = "",
          },
        },
        -- Ensure proper icon rendering
        icon = {
          folder_closed = "",
          folder_open = "",
          folder_empty = "",
          default = "",
        },
      },
      -- Ensure filesystem uses icons
      filesystem = {
        components = {
          -- Use default components which include icons
        },
      },
    },
  },

  -- Ensure mini.icons has proper Rust/Cargo icons
  {
    "nvim-mini/mini.icons",
    opts = {
      file = {
        -- Rust-specific files
        ["Cargo.toml"] = { glyph = "", hl = "MiniIconsOrange" },
        ["Cargo.lock"] = { glyph = "", hl = "MiniIconsGrey" },
        ["rust-toolchain.toml"] = { glyph = "", hl = "MiniIconsOrange" },
        [".rustfmt.toml"] = { glyph = "", hl = "MiniIconsOrange" },
        ["rustfmt.toml"] = { glyph = "", hl = "MiniIconsOrange" },
        -- Other common files
        [".gitignore"] = { glyph = "", hl = "MiniIconsGrey" },
        [".gitattributes"] = { glyph = "", hl = "MiniIconsGrey" },
        [".gitmodules"] = { glyph = "", hl = "MiniIconsGrey" },
        ["Makefile"] = { glyph = "", hl = "MiniIconsGrey" },
        ["Dockerfile"] = { glyph = "󰡨", hl = "MiniIconsBlue" },
        [".dockerignore"] = { glyph = "󰡨", hl = "MiniIconsGrey" },
      },
      extension = {
        rs = { glyph = "", hl = "MiniIconsOrange" },
        toml = { glyph = "", hl = "MiniIconsGrey" },
        lock = { glyph = "", hl = "MiniIconsGrey" },
      },
    },
  },
}
