-- Follow macOS appearance
local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
local result = handle:read("*a")
handle:close()
vim.o.background = result:match("Dark") and "dark" or "light"

-- Omarchy defaults
vim.opt.relativenumber = false
vim.opt.swapfile = false

-- Preserved from previous config
vim.opt.scrolloff = 4
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.breakindent = true
