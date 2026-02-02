-- Relative line numbers
vim.wo.relativenumber = true

-- Show line number
vim.wo.number = true

-- Ensure lines are visible when scrolling
vim.opt.scrolloff = 4

-- Tabs / spaces
vim.o.tabstop = 2  -- Tab looks like 4 spaces 
vim.o.expandtab = true  -- Convert tabs to spaces
vim.o.softtabstop = 2  -- 2 spaces inserted for tab
vim.o.shiftwidth = 2  -- 2 spaces inserted when indenting

-- Sync OS and Neovim clipboard
vim.o.clipboard = "unnamedplus"

-- Show long lines 
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive search unless
-- \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true
