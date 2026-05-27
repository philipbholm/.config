-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Copy file paths to clipboard
vim.keymap.set("n", "<leader>yp", function()
  local path = vim.fn.expand("%:.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Copy relative path" })

vim.keymap.set("n", "<leader>yP", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Copy full path" })

-- Move lines (replaces LazyVim's Alt+j/k, which clashes with AeroSpace)
vim.keymap.set("n", "øe", "<cmd>m .-2<cr>==", { desc = "Move line up" })
vim.keymap.set("n", "æe", "<cmd>m .+1<cr>==", { desc = "Move line down" })
vim.keymap.set("v", "øe", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })
vim.keymap.set("v", "æe", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
