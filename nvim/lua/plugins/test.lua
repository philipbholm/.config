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
  },
}
