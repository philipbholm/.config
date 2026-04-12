-- Follow macOS appearance by watching the symlink that switch-theme.sh updates
local theme_file = vim.fn.expand("~/.config/alacritty/active_theme.toml")

local function sync_appearance(reload)
  local link = vim.uv.fs_readlink(theme_file)
  if not link then
    local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    link = result:match("Dark") and "dark" or ""
  end
  local bg = link:match("dark") and "dark" or "light"
  if vim.o.background ~= bg then
    if reload then
      require("vscode").load(bg)
    else
      vim.o.background = bg
    end
  end
end

sync_appearance(false)

if _G._theme_timer then
  _G._theme_timer:stop()
  _G._theme_timer:close()
end
local timer = vim.uv.new_timer()
_G._theme_timer = timer
timer:start(5000, 5000, vim.schedule_wrap(function()
  sync_appearance(true)
end))

-- Omarchy defaults
vim.opt.relativenumber = true
vim.opt.swapfile = false

-- Preserved from previous config
vim.opt.scrolloff = 4
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.breakindent = true
