-- Debug Adapter Protocol (DAP) - Full debugging support
-- Languages: Go, Rust, C, C++, Zig, Python, JavaScript, TypeScript, Java
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      "theHamsta/nvim-dap-virtual-text",
      { "jay-babu/mason-nvim-dap.nvim", dependencies = { "mason-org/mason.nvim" } },
      "mxsdev/nvim-dap-vscode-js",
      { "microsoft/vscode-js-debug", build = "npm install --legacy-peer-deps --ignore-scripts && npx gulp dapDebugServer && mv dist out && git checkout -- package-lock.json" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- macOS: use system binaries from brew; Linux: use Mason paths
      local is_mac = vim.fn.has("mac") == 1
      local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

      -- Enable DAP logging for debugging
      dap.set_log_level("TRACE")

      -- Mason DAP setup — on macOS, debug adapters are installed via brew
      require("mason-nvim-dap").setup({
        ensure_installed = is_mac and {} or { "delve", "codelldb", "python", "js", "javadbg", "javatest" },
        automatic_installation = not is_mac,
      })

      -- DAP UI setup
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        layouts = {
          { elements = { { id = "scopes", size = 0.4 }, { id = "breakpoints", size = 0.15 }, { id = "stacks", size = 0.3 }, { id = "watches", size = 0.15 } }, size = 60, position = "left" },
          { elements = { { id = "repl", size = 0.5 }, { id = "console", size = 0.5 } }, size = 12, position = "bottom" },
        },
        floating = { border = "rounded", mappings = { close = { "q", "<Esc>" } } },
        expand_lines = true,  -- Expand lines that don't fit
        render = {
          max_type_length = nil,  -- No limit on type length
          max_value_lines = 100,  -- Allow up to 100 lines for values
          indent = 1,
        },
      })

      -- Enable word wrap in DAP UI windows when they open
      local function set_dapui_wrap()
        vim.schedule(function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.bo[buf].filetype
            if ft:match("^dapui") or ft == "dap-repl" then
              vim.wo[win].wrap = true
              vim.wo[win].linebreak = true
              vim.wo[win].breakindent = true
            end
          end
        end)
      end

      -- Hook into dapui open events
      local dapui_group = vim.api.nvim_create_augroup("DapUIWrap", { clear = true })
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = dapui_group,
        callback = function()
          local ft = vim.bo.filetype
          if ft:match("^dapui") or ft == "dap-repl" then
            vim.wo.wrap = true
            vim.wo.linebreak = true
            vim.wo.breakindent = true
          end
        end,
      })

      -- Also set wrap when debug session starts
      dap.listeners.after.event_initialized["dapui_wrap"] = set_dapui_wrap

      -- Virtual text
      require("nvim-dap-virtual-text").setup({ enabled = true, highlight_changed_variables = true, show_stop_reason = true })

      ------------------------------------------------------------------------------
      -- PROJECT ROOT DETECTION HELPERS
      ------------------------------------------------------------------------------
      -- Generic function to find project root by marker file
      local function find_project_root(markers)
        local file_dir = vim.fn.expand("%:p:h")
        for _, marker in ipairs(markers) do
          local found = vim.fn.findfile(marker, file_dir .. ";")
          if found ~= "" then
            return vim.fn.fnamemodify(found, ":p:h")
          end
          -- Also check for directories (like .git)
          local found_dir = vim.fn.finddir(marker, file_dir .. ";")
          if found_dir ~= "" then
            return vim.fn.fnamemodify(found_dir, ":p:h")
          end
        end
        return file_dir
      end

      -- Language-specific project root finders
      local function get_go_root()
        return find_project_root({ "go.mod", "go.work", ".git" })
      end

      local function get_rust_root()
        return find_project_root({ "Cargo.toml", ".git" })
      end

      local function get_zig_root()
        return find_project_root({ "build.zig", "build.zig.zon", ".git" })
      end

      local function get_js_root()
        return find_project_root({ "package.json", "tsconfig.json", ".git" })
      end

      local function get_python_root()
        return find_project_root({ "pyproject.toml", "setup.py", "requirements.txt", ".venv", "venv", ".git" })
      end

      local function get_java_root()
        return find_project_root({ "pom.xml", "build.gradle", "build.gradle.kts", ".git" })
      end

      local function get_c_cpp_root()
        return find_project_root({ "CMakeLists.txt", "Makefile", "compile_commands.json", ".git" })
      end

      ------------------------------------------------------------------------------
      -- GO (delve)
      ------------------------------------------------------------------------------
      dap.adapters.go = function(callback, config)
        local cwd = config.dlvCwd
        if type(cwd) == "function" then
          cwd = cwd()
        end
        cwd = cwd or get_go_root()
        
        callback({
          type = "server",
          port = "${port}",
          executable = {
            command = is_mac and "dlv" or (mason_bin .. "dlv"),
            args = { "dap", "-l", "127.0.0.1:${port}" },
            cwd = cwd,
          },
        })
      end

      dap.configurations.go = {
        {
          type = "go",
          name = "Debug File",
          request = "launch",
          mode = "debug",
          program = "${file}",
          dlvCwd = get_go_root,
        },
        {
          type = "go",
          name = "Debug Package",
          request = "launch",
          mode = "debug",
          program = "${fileDirname}",
          dlvCwd = get_go_root,
        },
        {
          type = "go",
          name = "Debug Test",
          request = "launch",
          mode = "test",
          program = "${fileDirname}",
          dlvCwd = get_go_root,
        },
        {
          type = "go",
          name = "Debug Test (go.mod)",
          request = "launch",
          mode = "test",
          program = ".",
          dlvCwd = get_go_root,
        },
        {
          type = "go",
          name = "Attach to Process",
          request = "attach",
          mode = "local",
          processId = require("dap.utils").pick_process,
        },
      }

      -- Auto open/close UI
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Signs
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "●", texthl = "DapBreakpointCondition" })
      vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DapLogPoint" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DapStopped", linehl = "DapStoppedLine" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DapBreakpointRejected" })

      -- Highlights
      vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e51400" })
      vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#ff9e64" })
      vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#61afef" })
      vim.api.nvim_set_hl(0, "DapStopped", { fg = "#98c379" })
      vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#2e4d3d" })
      vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#656565" })

      ------------------------------------------------------------------------------
      -- RUST / C / C++ (codelldb)
      ------------------------------------------------------------------------------
      dap.adapters.codelldb = function(callback, config)
        local cwd = config.projectRoot
        if type(cwd) == "function" then
          cwd = cwd()
        end
        
        callback({
          type = "server",
          port = "${port}",
          executable = {
            command = is_mac and "codelldb" or (mason_bin .. "codelldb"),
            args = { "--port", "${port}" },
            cwd = cwd,
          },
        })
      end

      -- NOTE: Rust configs moved to bottom (after Java) - rustaceanvim provides better DAP integration

      dap.configurations.c = {
        {
          name = "Debug Binary",
          type = "codelldb",
          request = "launch",
          program = function()
            local root = get_c_cpp_root()
            return vim.fn.input("Path to executable: ", root .. "/", "file")
          end,
          cwd = get_c_cpp_root,
          projectRoot = get_c_cpp_root,
          stopOnEntry = false,
        },
        {
          name = "Attach to Process",
          type = "codelldb",
          request = "attach",
          pid = require("dap.utils").pick_process,
          projectRoot = get_c_cpp_root,
        },
      }
      dap.configurations.cpp = dap.configurations.c

      ------------------------------------------------------------------------------
      -- ZIG (codelldb)
      ------------------------------------------------------------------------------
      dap.configurations.zig = {
        {
          name = "Debug Binary",
          type = "codelldb",
          request = "launch",
          program = function()
            local root = get_zig_root()
            return vim.fn.input("Path to executable: ", root .. "/zig-out/bin/", "file")
          end,
          cwd = get_zig_root,
          projectRoot = get_zig_root,
          stopOnEntry = false,
        },
        {
          name = "Debug Test",
          type = "codelldb",
          request = "launch",
          program = function()
            local root = get_zig_root()
            -- Build with debug info
            vim.fn.system("cd " .. root .. " && zig build 2>/dev/null")
            return vim.fn.input("Path to executable: ", root .. "/zig-out/bin/", "file")
          end,
          cwd = get_zig_root,
          projectRoot = get_zig_root,
          stopOnEntry = false,
        },
        {
          name = "Attach to Process",
          type = "codelldb",
          request = "attach",
          pid = require("dap.utils").pick_process,
          projectRoot = get_zig_root,
        },
      }

      ------------------------------------------------------------------------------
      -- PYTHON (debugpy)
      ------------------------------------------------------------------------------
      local function get_python_path()
        local root = get_python_root()
        -- Check for virtual environment in project
        local venv_paths = {
          root .. "/.venv/bin/python",
          root .. "/venv/bin/python",
          root .. "/.env/bin/python",
          root .. "/env/bin/python",
        }
        for _, venv in ipairs(venv_paths) do
          if vim.fn.executable(venv) == 1 then
            return venv
          end
        end
        -- Check VIRTUAL_ENV environment variable
        local env_venv = os.getenv("VIRTUAL_ENV")
        if env_venv then
          return env_venv .. "/bin/python"
        end
        -- Fallback to system python
        return "/usr/bin/python3"
      end

      dap.adapters.python = {
        type = "executable",
        command = is_mac and "python3" or (vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"),
        args = { "-m", "debugpy.adapter" },
      }

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Debug File",
          program = "${file}",
          cwd = get_python_root,
          pythonPath = get_python_path,
        },
        {
          type = "python",
          request = "launch",
          name = "Debug File with Arguments",
          program = "${file}",
          args = function() return vim.split(vim.fn.input("Arguments: "), " ") end,
          cwd = get_python_root,
          pythonPath = get_python_path,
        },
        {
          type = "python",
          request = "launch",
          name = "Debug Module",
          module = function() return vim.fn.input("Module name: ") end,
          cwd = get_python_root,
          pythonPath = get_python_path,
        },
        {
          type = "python",
          request = "launch",
          name = "Debug pytest",
          module = "pytest",
          args = { "${file}", "-v" },
          cwd = get_python_root,
          pythonPath = get_python_path,
        },
        {
          type = "python",
          request = "attach",
          name = "Attach to Process",
          connect = {
            host = "127.0.0.1",
            port = function() return tonumber(vim.fn.input("Port: ", "5678")) end,
          },
          cwd = get_python_root,
          pythonPath = get_python_path,
        },
      }

      ------------------------------------------------------------------------------
      -- JAVASCRIPT / TYPESCRIPT (vscode-js-debug)
      ------------------------------------------------------------------------------
      require("dap-vscode-js").setup({
        debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug",
        adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
      })

      for _, lang in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.configurations[lang] = {
          -- Node.js
          {
            type = "pwa-node",
            request = "launch",
            name = "Debug File (Node)",
            program = "${file}",
            cwd = get_js_root,
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach to Node Process",
            processId = require("dap.utils").pick_process,
            cwd = get_js_root,
          },
          -- Jest
          {
            type = "pwa-node",
            request = "launch",
            name = "Debug Jest Tests",
            runtimeExecutable = "node",
            runtimeArgs = function()
              local root = get_js_root()
              return { root .. "/node_modules/jest/bin/jest.js", "--runInBand", "${file}" }
            end,
            rootPath = get_js_root,
            cwd = get_js_root,
            console = "integratedTerminal",
            internalConsoleOptions = "neverOpen",
          },
          -- Mocha
          {
            type = "pwa-node",
            request = "launch",
            name = "Debug Mocha Tests",
            runtimeExecutable = "node",
            runtimeArgs = function()
              local root = get_js_root()
              return { root .. "/node_modules/mocha/bin/mocha.js", "${file}" }
            end,
            rootPath = get_js_root,
            cwd = get_js_root,
            console = "integratedTerminal",
          },
          -- Vitest
          {
            type = "pwa-node",
            request = "launch",
            name = "Debug Vitest Tests",
            runtimeExecutable = "node",
            runtimeArgs = function()
              local root = get_js_root()
              return { root .. "/node_modules/vitest/vitest.mjs", "run", "${file}" }
            end,
            rootPath = get_js_root,
            cwd = get_js_root,
            console = "integratedTerminal",
          },
          -- Chrome
          {
            type = "pwa-chrome",
            request = "launch",
            name = "Debug in Chrome",
            url = function() return vim.fn.input("URL: ", "http://localhost:3000") end,
            webRoot = get_js_root,
          },
          -- Next.js
          {
            type = "pwa-node",
            request = "launch",
            name = "Debug Next.js",
            runtimeExecutable = "node",
            runtimeArgs = function()
              local root = get_js_root()
              return { root .. "/node_modules/next/dist/bin/next", "dev" }
            end,
            cwd = get_js_root,
            console = "integratedTerminal",
          },
        }
      end

      ------------------------------------------------------------------------------
      -- JAVA (jdtls)
      ------------------------------------------------------------------------------
      dap.configurations.java = {
        {
          type = "java",
          request = "launch",
          name = "Debug Main Class",
          mainClass = function() return vim.fn.input("Main class: ") end,
          cwd = get_java_root,
        },
        {
          type = "java",
          request = "launch",
          name = "Debug Main Class with Arguments",
          mainClass = function() return vim.fn.input("Main class: ") end,
          args = function() return vim.fn.input("Arguments: ") end,
          cwd = get_java_root,
        },
        {
          type = "java",
          request = "attach",
          name = "Attach to Process (5005)",
          hostName = "127.0.0.1",
          port = 5005,
          cwd = get_java_root,
        },
        {
          type = "java",
          request = "attach",
          name = "Attach to Process (Custom Port)",
          hostName = "127.0.0.1",
          port = function() return tonumber(vim.fn.input("Port: ", "5005")) end,
          cwd = get_java_root,
        },
      }

      ------------------------------------------------------------------------------
      -- RUST (codelldb) - Fallback configs, rustaceanvim provides better integration
      -- Use :RustLsp debug for smart debugging with rustaceanvim
      ------------------------------------------------------------------------------
      dap.configurations.rust = {
        {
          name = "Debug Binary (manual)",
          type = "codelldb",
          request = "launch",
          program = function()
            local root = get_rust_root()
            return vim.fn.input("Path to executable: ", root .. "/target/debug/", "file")
          end,
          cwd = get_rust_root,
          projectRoot = get_rust_root,
          stopOnEntry = false,
        },
        {
          name = "Debug Release Binary (manual)",
          type = "codelldb",
          request = "launch",
          program = function()
            local root = get_rust_root()
            return vim.fn.input("Path to executable: ", root .. "/target/release/", "file")
          end,
          cwd = get_rust_root,
          projectRoot = get_rust_root,
          stopOnEntry = false,
        },
        {
          name = "Debug Test (manual)",
          type = "codelldb",
          request = "launch",
          program = function()
            -- Build tests first
            local root = get_rust_root()
            vim.fn.system("cd " .. root .. " && cargo test --no-run 2>/dev/null")
            -- Find the test binary
            local test_binary = vim.fn.glob(root .. "/target/debug/deps/*-*")
            if test_binary ~= "" then
              local binaries = vim.split(test_binary, "\n")
              -- Filter to only executable files (not .d files)
              local exes = {}
              for _, b in ipairs(binaries) do
                if not b:match("%.d$") and vim.fn.executable(b) == 1 then
                  table.insert(exes, b)
                end
              end
              if #exes > 0 then
                return vim.fn.input("Test binary: ", exes[1], "file")
              end
            end
            return vim.fn.input("Path to test binary: ", root .. "/target/debug/deps/", "file")
          end,
          cwd = get_rust_root,
          projectRoot = get_rust_root,
          stopOnEntry = false,
        },
        {
          name = "Attach to Process",
          type = "codelldb",
          request = "attach",
          pid = require("dap.utils").pick_process,
          projectRoot = get_rust_root,
        },
      }

      ------------------------------------------------------------------------------
      -- KEYBINDINGS
      ------------------------------------------------------------------------------
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
      vim.keymap.set("n", "<leader>dB", function() dap.set_breakpoint(vim.fn.input("Condition: ")) end, { desc = "Debug: Conditional Breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: Continue/Start" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into" })
      vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Debug: Step Over" })
      vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Debug: Step Out" })
      vim.keymap.set("n", "<leader>dr", dap.restart, { desc = "Debug: Restart" })
      vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Debug: Terminate" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
      vim.keymap.set({ "n", "v" }, "<leader>de", dapui.eval, { desc = "Debug: Evaluate" })
      vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run Last" })
      vim.keymap.set("n", "<leader>dp", dap.pause, { desc = "Debug: Pause" })
    end,
  },
}
