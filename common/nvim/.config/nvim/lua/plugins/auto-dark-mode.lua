return {
  "f-person/auto-dark-mode.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    update_interval = 3000,
    set_dark_mode = function()
      vim.api.nvim_set_option_value("background", "dark", {})
      vim.cmd("colorscheme gruvbox-material")
    end,
    set_light_mode = function()
      vim.api.nvim_set_option_value("background", "light", {})
      -- Use tokyonight-moon as the default light theme
      vim.cmd("colorscheme tokyonight-moon")
    end,
  },
}
