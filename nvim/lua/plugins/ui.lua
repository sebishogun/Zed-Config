-- ui.lua - UI customizations for neo-tree, icons, mode-colored lualine bar,
-- orange LazyVim dashboard logo, and automatic terminal zoom on Neovim startup.

-- Build the IntelliJ full-bar mode-colored lualine theme:
-- Section `a` (badge), `b` (sub-bar), and `c` (entire bottom bar background)
-- all shift color together when changing between Normal, Insert, Visual,
-- Command, Replace, and Terminal modes.
local function intellij_mode_bar_theme()
  local fg_light = "#F0F0F0"
  local fg_dark = "#000000"
  return {
    normal = {
      a = { bg = "#56A8F5", fg = fg_dark, gui = "bold" }, -- IntelliJ Blue badge
      b = { bg = "#214283", fg = fg_light },
      c = { bg = "#16294D", fg = fg_light },              -- Deep Blue bar background
    },
    insert = {
      a = { bg = "#90C35A", fg = fg_dark, gui = "bold" }, -- IntelliJ Green badge
      b = { bg = "#2D543F", fg = fg_light },
      c = { bg = "#1B3626", fg = fg_light },              -- Deep Green bar background
    },
    visual = {
      a = { bg = "#C77DBA", fg = fg_dark, gui = "bold" }, -- IntelliJ Purple badge
      b = { bg = "#4D2948", fg = fg_light },
      c = { bg = "#2E182B", fg = fg_light },              -- Deep Purple bar background
    },
    command = {
      a = { bg = "#EBA055", fg = fg_dark, gui = "bold" }, -- IntelliJ Orange badge
      b = { bg = "#5E3C18", fg = fg_light },
      c = { bg = "#38230E", fg = fg_light },              -- Deep Amber/Orange bar background
    },
    replace = {
      a = { bg = "#E05555", fg = fg_dark, gui = "bold" }, -- IntelliJ Crimson badge
      b = { bg = "#5E2020", fg = fg_light },
      c = { bg = "#381313", fg = fg_light },              -- Deep Crimson bar background
    },
    terminal = {
      a = { bg = "#2AACB8", fg = fg_dark, gui = "bold" }, -- IntelliJ Teal badge
      b = { bg = "#1A4D53", fg = fg_light },
      c = { bg = "#102F33", fg = fg_light },              -- Deep Teal bar background
    },
    inactive = {
      a = { bg = "#14151A", fg = "#7A7E85", gui = "bold" },
      b = { bg = "#14151A", fg = "#7A7E85" },
      c = { bg = "#14151A", fg = "#7A7E85" },
    },
  }
end

-- Find the ancestor terminal emulator PID (ghostty / kitty / alacritty / foot)
-- for the current Neovim instance by walking /proc/<pid>/stat.
local function find_terminal_pid()
  local pid = vim.fn.getpid()
  local terms = { ghostty = true, kitty = true, alacritty = true, foot = true, wezterm = true }
  for _ = 1, 12 do
    if not pid or pid <= 1 then
      break
    end
    local f = io.open("/proc/" .. pid .. "/stat", "r")
    if not f then
      break
    end
    local stat = f:read("*a")
    f:close()
    if not stat then
      break
    end
    local comm, rest = stat:match("^%d+%s+%((.-)%)%s+(.*)$")
    if comm and terms[comm] then
      return pid
    end
    local ppid = rest and tonumber(rest:match("^%S+%s+(%d+)"))
    pid = ppid
  end
  return nil
end

local cached_term_pid = nil

-- Send a Ctrl+<key> chord to the ancestor terminal window in Hyprland
local function send_terminal_zoom_key(key, count)
  count = count or 1
  if #vim.api.nvim_list_uis() == 0 then
    return
  end
  if vim.fn.executable("hyprctl") ~= 1 then
    return
  end
  cached_term_pid = cached_term_pid or find_terminal_pid()
  local win_target = cached_term_pid and string.format(", window = %q", "pid:" .. cached_term_pid) or ""
  local lua_expr = string.format(
    [[
local function step(i)
  hl.dispatch(hl.dsp.send_key_state({ mods = "CTRL", key = %q, state = "down"%s }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = "CTRL", key = %q, state = "up"%s }))
    if i < %d then
      hl.timer(function() step(i + 1) end, { timeout = 20, type = "oneshot" })
    end
  end, { timeout = 20, type = "oneshot" })
end
step(1)
]],
    key,
    win_target,
    key,
    win_target,
    count
  )
  vim.fn.jobstart({ "hyprctl", "eval", lua_expr }, { detach = true })
end

return {
  -- 1. Full Mode-Colored Bottom Statusline Bar (lualine.nvim) + Auto-Zoom on Startup
  {
    "nvim-lualine/lualine.nvim",
    init = function()
      -- Default number of zoom-in steps when opening Neovim (set to 0 to disable)
      if vim.g.nvim_auto_zoom_steps == nil then
        vim.g.nvim_auto_zoom_steps = 2
      end

      local group = vim.api.nvim_create_augroup("NvimTerminalAutoZoom", { clear = true })
      local zoomed_on_enter = false

      vim.api.nvim_create_autocmd("UIEnter", {
        group = group,
        once = true,
        callback = function()
          local steps = tonumber(vim.g.nvim_auto_zoom_steps) or 0
          if steps > 0 then
            zoomed_on_enter = true
            send_terminal_zoom_key("equal", steps)
          end
        end,
      })

      vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
          if zoomed_on_enter then
            send_terminal_zoom_key("0", 1)
          end
        end,
      })

      vim.api.nvim_create_user_command("ZoomIn", function(opts)
        local n = tonumber(opts.args) or 1
        send_terminal_zoom_key("equal", n)
      end, { nargs = "?", desc = "Zoom in terminal font size" })

      vim.api.nvim_create_user_command("ZoomOut", function(opts)
        local n = tonumber(opts.args) or 1
        send_terminal_zoom_key("minus", n)
      end, { nargs = "?", desc = "Zoom out terminal font size" })

      vim.api.nvim_create_user_command("ZoomReset", function()
        send_terminal_zoom_key("0", 1)
      end, { desc = "Reset terminal font size to default" })
    end,
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.theme = intellij_mode_bar_theme()
      opts.options.section_separators = { left = "", right = "" }
      opts.options.component_separators = { left = "", right = "" }

      -- Replace Trouble's hardcoded `lualine_c_normal` statusline item (which creates a
      -- dark patch when the bar changes color in Insert/Visual/Command mode) with a
      -- mode-transparent symbol breadcrumb that inherits the active mode's bar background.
      if opts.sections and opts.sections.lualine_c and LazyVim.has("trouble.nvim") then
        local ok, trouble = pcall(require, "trouble")
        if ok then
          local symbols = trouble.statusline({
            mode = "symbols",
            groups = {},
            title = false,
            filter = { range = true },
            format = "{kind_icon}{symbol.name}",
          })
          opts.sections.lualine_c[#opts.sections.lualine_c] = {
            function()
              local raw = (symbols and symbols.get and symbols.get()) or ""
              return raw:gsub("%%#[^#]*#", "")
            end,
            cond = function()
              return vim.b.trouble_lualine ~= false and symbols and symbols.has and symbols.has()
            end,
          }
        end
      end

      -- Keep lualine mode-colored theme active even after Omarchy / ColorScheme reloads
      local group = vim.api.nvim_create_augroup("IntelliJLualineTheme", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
          vim.schedule(function()
            local ok_ll, lualine = pcall(require, "lualine")
            if ok_ll then
              opts.options.theme = intellij_mode_bar_theme()
              lualine.setup(opts)
            end
          end)
        end,
      })

      return opts
    end,
    keys = {
      { "<leader>u+", "<cmd>ZoomIn<cr>", desc = "Zoom In Terminal Font" },
      { "<leader>u-", "<cmd>ZoomOut<cr>", desc = "Zoom Out Terminal Font" },
      { "<leader>uz", "<cmd>ZoomReset<cr>", desc = "Reset Terminal Zoom" },
    },
  },

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
