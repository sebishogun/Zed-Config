return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local harpoon = require("harpoon")
    harpoon:setup()

    -- Add file to harpoon (ignore special buffers like neo-tree)
    vim.keymap.set("n", "<leader>a", function()
      local buftype = vim.bo.buftype
      local filetype = vim.bo.filetype
      -- Ignore special buffers
      if buftype ~= "" or filetype == "neo-tree" or filetype == "NvimTree" then
        vim.notify("Can't harpoon this buffer", vim.log.levels.WARN)
        return
      end
      harpoon:list():add()
    end, { desc = "Harpoon add file" })

    -- Toggle harpoon menu
    vim.keymap.set("n", "<leader>h", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon menu" })

    -- Quick navigation with number row (1-9, 0)
    vim.keymap.set("n", "<leader>1", function() harpoon:list():select(1) end, { desc = "Harpoon file 1" })
    vim.keymap.set("n", "<leader>2", function() harpoon:list():select(2) end, { desc = "Harpoon file 2" })
    vim.keymap.set("n", "<leader>3", function() harpoon:list():select(3) end, { desc = "Harpoon file 3" })
    vim.keymap.set("n", "<leader>4", function() harpoon:list():select(4) end, { desc = "Harpoon file 4" })
    vim.keymap.set("n", "<leader>5", function() harpoon:list():select(5) end, { desc = "Harpoon file 5" })
    vim.keymap.set("n", "<leader>6", function() harpoon:list():select(6) end, { desc = "Harpoon file 6" })
    vim.keymap.set("n", "<leader>7", function() harpoon:list():select(7) end, { desc = "Harpoon file 7" })
    vim.keymap.set("n", "<leader>8", function() harpoon:list():select(8) end, { desc = "Harpoon file 8" })
    vim.keymap.set("n", "<leader>9", function() harpoon:list():select(9) end, { desc = "Harpoon file 9" })
    vim.keymap.set("n", "<leader>0", function() harpoon:list():select(10) end, { desc = "Harpoon file 10" })

    -- Quick navigation with numpad
    vim.keymap.set("n", "<leader><k1>", function() harpoon:list():select(1) end, { desc = "Harpoon file 1" })
    vim.keymap.set("n", "<leader><k2>", function() harpoon:list():select(2) end, { desc = "Harpoon file 2" })
    vim.keymap.set("n", "<leader><k3>", function() harpoon:list():select(3) end, { desc = "Harpoon file 3" })
    vim.keymap.set("n", "<leader><k4>", function() harpoon:list():select(4) end, { desc = "Harpoon file 4" })
    vim.keymap.set("n", "<leader><k5>", function() harpoon:list():select(5) end, { desc = "Harpoon file 5" })
    vim.keymap.set("n", "<leader><k6>", function() harpoon:list():select(6) end, { desc = "Harpoon file 6" })
    vim.keymap.set("n", "<leader><k7>", function() harpoon:list():select(7) end, { desc = "Harpoon file 7" })
    vim.keymap.set("n", "<leader><k8>", function() harpoon:list():select(8) end, { desc = "Harpoon file 8" })
    vim.keymap.set("n", "<leader><k9>", function() harpoon:list():select(9) end, { desc = "Harpoon file 9" })
    vim.keymap.set("n", "<leader><k0>", function() harpoon:list():select(10) end, { desc = "Harpoon file 10" })

    -- Navigate prev/next
    vim.keymap.set("n", "<leader>[", function() harpoon:list():prev() end, { desc = "Harpoon prev" })
    vim.keymap.set("n", "<leader>]", function() harpoon:list():next() end, { desc = "Harpoon next" })
  end,
}
