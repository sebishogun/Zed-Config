-- intellij-assists.lua
-- IntelliJ IDEA-style Inlay Hints (spaced pills, caret-pause line hints, or EOL),
-- Auto-Hover Type Panel on caret pause / mouse hover, on-demand Type Info actions,
-- IntelliJ-style Autocomplete (blink.cmp) + Signature Help (noice.nvim),
-- and instant commands/keymaps to toggle any or all of them.

local M = {}

---@class IntelliJAssistsState
---@field hint_mode "spaced"|"caret"|"eol"|"off"
---@field prev_active_mode "spaced"|"caret"|"eol"
---@field auto_hover boolean
---@field autocomplete boolean
---@field all_enabled boolean
local state = {
  hint_mode = "spaced", -- "spaced" | "caret" | "eol" | "off"
  prev_active_mode = "spaced",
  auto_hover = false,   -- Toggle with <leader>uk or :AutoHoverToggle (on-demand K / <leader>ci always works!)
  autocomplete = true,  -- Toggle with <leader>ua or :AutocompleteToggle
  all_enabled = true,   -- Master toggle with <leader>uA or :IntelliJAssistsToggle
}

vim.g.intellij_autocomplete_enabled = state.autocomplete

local eol_ns = vim.api.nvim_create_namespace("intellij_inlay_eol")
local raw_hint_cache = {} ---@type table<integer, table<integer, { result: table[], ctx: table }>>
local caret_visible_line = {} ---@type table<integer, integer?>
local orig_on_inlayhint = nil

local function extract_label_text(label)
  if type(label) == "string" then
    return label
  elseif type(label) == "table" then
    local parts = {}
    for _, part in ipairs(label) do
      parts[#parts + 1] = part.value or ""
    end
    return table.concat(parts)
  end
  return ""
end

local function format_spaced_hint(hint)
  local h = vim.deepcopy(hint)
  local raw = vim.trim(extract_label_text(h.label))
  if raw == "" then
    return h
  end
  -- Add internal pill padding (" *http.Response " / " format: ")
  -- plus outer spacing (paddingLeft & paddingRight) so pills never touch
  -- adjacent commas, parentheses, or identifiers.
  h.label = " " .. raw .. " "
  h.paddingLeft = true
  h.paddingRight = true
  return h
end

local function render_eol_hints(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, eol_ns, 0, -1)
  local buf_cache = raw_hint_cache[bufnr]
  if not buf_cache then
    return
  end

  local by_line = {} ---@type table<integer, string[]>
  for _, entry in pairs(buf_cache) do
    for _, hint in ipairs(entry.result or {}) do
      local lnum = hint.position and hint.position.line
      if lnum then
        local raw = vim.trim(extract_label_text(hint.label))
        if raw ~= "" then
          by_line[lnum] = by_line[lnum] or {}
          table.insert(by_line[lnum], raw)
        end
      end
    end
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for lnum, items in pairs(by_line) do
    if lnum >= 0 and lnum < line_count and #items > 0 then
      local summary = "  " .. table.concat(items, "  •  ") .. " "
      pcall(vim.api.nvim_buf_set_extmark, bufnr, eol_ns, lnum, 0, {
        virt_text = {
          { "   ", "Normal" },
          { summary, "LspInlayHint" },
        },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end
  end
end

local function apply_cached_hints(bufnr)
  if not orig_on_inlayhint then
    return
  end
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, eol_ns, 0, -1)
  local buf_cache = raw_hint_cache[bufnr]
  if not buf_cache then
    return
  end

  local cur_ver = vim.lsp.util.buf_versions[bufnr]
  for _, entry in pairs(buf_cache) do
    local ctx = vim.deepcopy(entry.ctx)
    if cur_ver then
      ctx.version = cur_ver
    end

    if state.hint_mode == "off" then
      orig_on_inlayhint(nil, {}, ctx)
    elseif state.hint_mode == "eol" then
      orig_on_inlayhint(nil, {}, ctx)
    elseif state.hint_mode == "caret" then
      local target_line = caret_visible_line[bufnr]
      local filtered = {}
      if target_line ~= nil then
        for _, hint in ipairs(entry.result or {}) do
          if hint.position and hint.position.line == target_line then
            filtered[#filtered + 1] = format_spaced_hint(hint)
          end
        end
      end
      orig_on_inlayhint(nil, filtered, ctx)
    else -- "spaced"
      local spaced = {}
      for _, hint in ipairs(entry.result or {}) do
        spaced[#spaced + 1] = format_spaced_hint(hint)
      end
      orig_on_inlayhint(nil, spaced, ctx)
    end
  end

  if state.hint_mode == "eol" then
    render_eol_hints(bufnr)
  end
end

local function refresh_all_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      apply_cached_hints(bufnr)
    end
  end
end

local function install_inlay_hint_hook()
  if orig_on_inlayhint then
    return
  end
  orig_on_inlayhint = vim.lsp.inlay_hint.on_inlayhint

  vim.lsp.inlay_hint.on_inlayhint = function(err, result, ctx)
    if err or not ctx or not ctx.bufnr then
      return orig_on_inlayhint(err, result, ctx)
    end
    local bufnr = ctx.bufnr
    local client_id = ctx.client_id or 0
    raw_hint_cache[bufnr] = raw_hint_cache[bufnr] or {}
    raw_hint_cache[bufnr][client_id] = {
      result = vim.deepcopy(result or {}),
      ctx = vim.deepcopy(ctx),
    }
    apply_cached_hints(bufnr)
  end
end

function M.set_hint_mode(mode, notify)
  if mode ~= "spaced" and mode ~= "caret" and mode ~= "eol" and mode ~= "off" then
    return
  end
  state.hint_mode = mode
  if mode ~= "off" then
    state.prev_active_mode = mode
    if not vim.lsp.inlay_hint.is_enabled() then
      vim.lsp.inlay_hint.enable(true)
    end
  else
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, eol_ns, 0, -1)
      end
    end
    vim.lsp.inlay_hint.enable(false)
  end

  if mode == "caret" then
    local bufnr = vim.api.nvim_get_current_buf()
    caret_visible_line[bufnr] = vim.api.nvim_win_get_cursor(0)[1] - 1
  end

  refresh_all_buffers()

  if notify ~= false then
    local descriptions = {
      spaced = "Spaced Inline Pills (all lines)",
      caret = "Caret-Pause Line Only (shows when cursor rests)",
      eol = "End-of-Line Summary (never shifts code)",
      off = "Disabled",
    }
    vim.notify("Inlay Hints Mode: " .. (descriptions[mode] or mode), vim.log.levels.INFO, {
      title = "IntelliJ Assists",
    })
  end
end

function M.cycle_hint_mode()
  local order = { "spaced", "caret", "eol", "off" }
  local next_mode = "spaced"
  for i, m in ipairs(order) do
    if m == state.hint_mode then
      next_mode = order[(i % #order) + 1]
      break
    end
  end
  M.set_hint_mode(next_mode, true)
end

function M.toggle_inlay_hints()
  if state.hint_mode == "off" then
    M.set_hint_mode(state.prev_active_mode or "spaced", true)
  else
    M.set_hint_mode("off", true)
  end
end

function M.show_type_info_panel(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })
  if #clients == 0 then
    if not opts.silent then
      vim.notify("No active LSP with hover support for this buffer", vim.log.levels.WARN, { title = "IntelliJ Assists" })
    end
    return
  end

  -- Check if cursor is on an actual word/symbol when triggered automatically
  if opts.silent then
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_get_current_line()
    local ch = line:sub(col + 1, col + 1)
    if ch == "" or not ch:match("[%w_]") then
      return
    end
  end

  local ok_noice, noice_lsp = pcall(require, "noice.lsp")
  if ok_noice and noice_lsp and noice_lsp.hover then
    noice_lsp.hover()
  else
    vim.lsp.buf.hover({ border = "rounded" })
  end
end

function M.toggle_auto_hover(val)
  if type(val) == "boolean" then
    state.auto_hover = val
  else
    state.auto_hover = not state.auto_hover
  end
  vim.notify(
    "Auto-Hover Type Panel (on caret pause): " .. (state.auto_hover and "ON" or "OFF"),
    vim.log.levels.INFO,
    { title = "IntelliJ Assists" }
  )
end

function M.toggle_autocomplete(val)
  if type(val) == "boolean" then
    state.autocomplete = val
  else
    state.autocomplete = not state.autocomplete
  end
  vim.g.intellij_autocomplete_enabled = state.autocomplete
  if not state.autocomplete then
    pcall(function()
      require("blink.cmp").hide()
    end)
  end
  vim.notify(
    "Autocomplete While Typing: " .. (state.autocomplete and "ON" or "OFF"),
    vim.log.levels.INFO,
    { title = "IntelliJ Assists" }
  )
end

function M.toggle_all_assists()
  state.all_enabled = not state.all_enabled
  if state.all_enabled then
    M.set_hint_mode(state.prev_active_mode or "spaced", false)
    state.auto_hover = true
    state.autocomplete = true
    vim.g.intellij_autocomplete_enabled = true
    vim.notify(
      "All IntelliJ Assists ENABLED (Inlay Hints: " .. state.hint_mode .. ", Auto-Hover: ON, Autocomplete: ON)",
      vim.log.levels.INFO,
      { title = "IntelliJ Assists" }
    )
  else
    M.set_hint_mode("off", false)
    state.auto_hover = false
    state.autocomplete = false
    vim.g.intellij_autocomplete_enabled = false
    pcall(function()
      require("blink.cmp").hide()
    end)
    vim.notify(
      "All IntelliJ Assists DISABLED (Inlay Hints: OFF, Auto-Hover: OFF, Autocomplete: OFF)",
      vim.log.levels.INFO,
      { title = "IntelliJ Assists" }
    )
  end
end

function M.open_assists_menu()
  local items = {
    {
      label = string.format("1. Inlay Hints: Spaced Inline Pills %s", state.hint_mode == "spaced" and "[ACTIVE]" or ""),
      action = function() M.set_hint_mode("spaced", true) end,
    },
    {
      label = string.format("2. Inlay Hints: Caret-Pause Current Line Only %s", state.hint_mode == "caret" and "[ACTIVE]" or ""),
      action = function() M.set_hint_mode("caret", true) end,
    },
    {
      label = string.format("3. Inlay Hints: End-of-Line Summary %s", state.hint_mode == "eol" and "[ACTIVE]" or ""),
      action = function() M.set_hint_mode("eol", true) end,
    },
    {
      label = string.format("4. Inlay Hints: Off %s", state.hint_mode == "off" and "[ACTIVE]" or ""),
      action = function() M.set_hint_mode("off", true) end,
    },
    {
      label = string.format("5. Toggle Auto-Hover Type Panel on Caret Pause (currently %s)", state.auto_hover and "ON" or "OFF"),
      action = function() M.toggle_auto_hover() end,
    },
    {
      label = string.format("6. Toggle Autocomplete While Typing (currently %s)", state.autocomplete and "ON" or "OFF"),
      action = function() M.toggle_autocomplete() end,
    },
    {
      label = "7. Show Type & Documentation Panel at Cursor Now (K / <leader>ci)",
      action = function() M.show_type_info_panel({ silent = false }) end,
    },
    {
      label = string.format("8. Master Toggle All Assists (currently %s)", state.all_enabled and "ON" or "OFF"),
      action = function() M.toggle_all_assists() end,
    },
  }

  vim.ui.select(items, {
    prompt = "IntelliJ Assists & Type Hints Control:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice and choice.action then
      choice.action()
    end
  end)
end

return {
  -- 1. IntelliJ-style Autocomplete (blink.cmp) with right-aligned Type column & rounded borders
  {
    "saghen/blink.cmp",
    opts = {
      enabled = function()
        return vim.g.intellij_autocomplete_enabled ~= false
      end,
      completion = {
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
        menu = {
          border = "rounded",
          max_height = 14,
          min_width = 32,
          winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
          draw = {
            padding = { 1, 1 },
            gap = 2,
            treesitter = { "lsp" },
            -- IntelliJ layout: [Icon] [Name + Params]      [Return/Var Type] [Kind]
            columns = {
              { "kind_icon" },
              { "label", gap = 1 },
              { "label_description" },
              { "kind" },
            },
            components = {
              label = {
                width = { fill = true, max = 55 },
              },
              label_description = {
                width = { max = 38 },
                highlight = "BlinkCmpLabelDescription",
              },
              kind = {
                highlight = "BlinkCmpKind",
              },
            },
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 120,
          treesitter_highlighting = true,
          window = {
            border = "rounded",
            max_width = 80,
            max_height = 22,
            winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc",
          },
        },
        ghost_text = {
          enabled = true,
        },
      },
      keymap = {
        preset = "enter",
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
      },
    },
  },

  -- 2. IntelliJ-style bordered Hover Type Panel & Top Function Signature Panel (noice.nvim)
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        lsp_doc_border = true, -- Rounded border on Hover Type Panel & Signature Help
      },
      lsp = {
        hover = {
          enabled = true,
          silent = true, -- Don't spam "No information available" when caret rests on whitespace
        },
        signature = {
          enabled = true,
          auto_open = {
            enabled = true,
            trigger = true,
            luasnip = true,
            throttle = 50,
          },
        },
      },
      views = {
        hover = {
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
          position = { row = 2, col = 2 },
          win_options = {
            winhighlight = {
              Normal = "NoicePopup",
              FloatBorder = "NoicePopupBorder",
            },
          },
        },
      },
    },
  },

  -- 3. Inlay Hints Spacing, Caret-Pause / EOL Modes, Auto-Hover & Commands/Keymaps
  {
    "neovim/nvim-lspconfig",
    init = function()
      -- Faster CursorHold (450ms) so caret-pause hints & auto-hover feel snappy like IntelliJ
      vim.opt.updatetime = 450
      vim.opt.mousemoveevent = true

      install_inlay_hint_hook()

      local group = vim.api.nvim_create_augroup("IntelliJAssists", { clear = true })

      -- Caret-pause handler: reveals current-line hints in "caret" mode
      -- and opens the floating Type/Doc panel if Auto-Hover is enabled.
      vim.api.nvim_create_autocmd("CursorHold", {
        group = group,
        callback = function(ev)
          if vim.fn.mode() ~= "n" then
            return
          end
          local win = vim.api.nvim_get_current_win()
          if vim.api.nvim_win_get_config(win).relative ~= "" then
            return -- Ignore inside floating windows
          end

          if state.hint_mode == "caret" then
            local line = vim.api.nvim_win_get_cursor(win)[1] - 1
            if caret_visible_line[ev.buf] ~= line then
              caret_visible_line[ev.buf] = line
              apply_cached_hints(ev.buf)
            end
          end

          if state.auto_hover then
            M.show_type_info_panel({ silent = true })
          end
        end,
      })

      -- Hide current-line hints when moving to another line or typing in "caret" mode
      vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter" }, {
        group = group,
        callback = function(ev)
          if state.hint_mode ~= "caret" then
            return
          end
          if vim.fn.mode():match("^i") then
            if caret_visible_line[ev.buf] ~= nil then
              caret_visible_line[ev.buf] = nil
              apply_cached_hints(ev.buf)
            end
            return
          end
          local line = vim.api.nvim_win_get_cursor(0)[1] - 1
          if caret_visible_line[ev.buf] ~= nil and caret_visible_line[ev.buf] ~= line then
            caret_visible_line[ev.buf] = nil
            apply_cached_hints(ev.buf)
          end
        end,
      })

      vim.api.nvim_create_autocmd("BufDelete", {
        group = group,
        callback = function(ev)
          raw_hint_cache[ev.buf] = nil
          caret_visible_line[ev.buf] = nil
        end,
      })

      -- User Commands for instant toggling
      vim.api.nvim_create_user_command("IntelliJAssists", function()
        M.open_assists_menu()
      end, { desc = "Open IntelliJ Assists & Type Hints control menu" })

      vim.api.nvim_create_user_command("IntelliJAssistsToggle", function()
        M.toggle_all_assists()
      end, { desc = "Master toggle for all IntelliJ assists (Inlay Hints, Auto-Hover, Autocomplete)" })

      vim.api.nvim_create_user_command("InlayHintsToggle", function()
        M.toggle_inlay_hints()
      end, { desc = "Toggle LSP Inlay Hints on/off" })

      vim.api.nvim_create_user_command("InlayHintsMode", function(cmd_opts)
        local arg = vim.trim(cmd_opts.args or "")
        if arg ~= "" then
          M.set_hint_mode(arg, true)
        else
          M.cycle_hint_mode()
        end
      end, {
        nargs = "?",
        complete = function()
          return { "spaced", "caret", "eol", "off" }
        end,
        desc = "Cycle or set Inlay Hints mode (spaced | caret | eol | off)",
      })

      vim.api.nvim_create_user_command("AutoHoverToggle", function()
        M.toggle_auto_hover()
      end, { desc = "Toggle automatic floating Type/Doc panel when caret pauses on a symbol" })

      vim.api.nvim_create_user_command("AutocompleteToggle", function()
        M.toggle_autocomplete()
      end, { desc = "Toggle autocomplete popup while typing" })
    end,
    keys = {
      {
        "<leader>uh",
        function() M.toggle_inlay_hints() end,
        desc = "Toggle Inlay Hints",
      },
      {
        "<leader>uH",
        function() M.cycle_hint_mode() end,
        desc = "Cycle Inlay Hints Mode (Spaced / Caret / EOL / Off)",
      },
      {
        "<leader>uk",
        function() M.toggle_auto_hover() end,
        desc = "Toggle Auto-Hover Type Panel (Caret Pause)",
      },
      {
        "<leader>ua",
        function() M.toggle_autocomplete() end,
        desc = "Toggle Autocomplete While Typing",
      },
      {
        "<leader>uA",
        function() M.toggle_all_assists() end,
        desc = "Master Toggle All IntelliJ Assists",
      },
      {
        "<leader>uI",
        function() M.open_assists_menu() end,
        desc = "IntelliJ Assists Menu (Hints, Hover, Completion)",
      },
      {
        "<leader>ci",
        function() M.show_type_info_panel({ silent = false }) end,
        desc = "Show Type & Documentation Info Panel",
      },
      {
        "<leader>ct",
        function() vim.lsp.buf.type_definition() end,
        desc = "Goto Type Definition",
      },
      {
        "<M-CR>",
        function() vim.lsp.buf.code_action() end,
        mode = { "n", "v", "i" },
        desc = "Code Action (IntelliJ Alt+Enter)",
      },
    },
  },
}
