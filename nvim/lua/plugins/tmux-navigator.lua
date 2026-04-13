return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Window Left" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Window Down" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Window Up" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Window Right" },
    },
    init = function()
      -- Buffer-local terminal keymaps via TermOpen override the plugin's
      -- broken global terminal maps (which use <C-w>: — Vim-only, not neovim).
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(args)
          local nav = { h = { "L", "Left" }, j = { "D", "Down" }, k = { "U", "Up" }, l = { "R", "Right" } }
          for key, dirs in pairs(nav) do
            vim.keymap.set("t", "<C-" .. key .. ">", function()
              if vim.api.nvim_win_get_config(0).relative ~= "" then
                -- Floating window (e.g. lazygit): wincmd would leave the float
                -- instead of reaching tmux, so navigate the tmux pane directly
                vim.fn.system("tmux select-pane -" .. dirs[1])
              else
                vim.cmd.stopinsert()
                if vim.fn.exists(":TmuxNavigate" .. dirs[2]) == 2 then
                  vim.cmd("TmuxNavigate" .. dirs[2])
                else
                  vim.cmd("wincmd " .. key)
                end
              end
            end, { buffer = args.buf, silent = true })
          end
        end,
      })
    end,
  },
}
