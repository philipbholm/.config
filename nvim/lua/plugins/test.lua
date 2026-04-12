return {
  {
    "marilari88/neotest-vitest",
    dependencies = { "nvim-neotest/neotest" },
  },
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        ["neotest-vitest"] = {},
      },
    },
    keys = {
      {
        "<leader>tt",
        function()
          vim.cmd("write")
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Run File (Neotest)",
      },
      {
        "<leader>tr",
        function()
          vim.cmd("write")
          require("neotest").run.run()
        end,
        desc = "Run Nearest (Neotest)",
      },
      {
        "<leader>tl",
        function()
          vim.cmd("write")
          require("neotest").run.run_last()
        end,
        desc = "Run Last (Neotest)",
      },
    },
  },
}
