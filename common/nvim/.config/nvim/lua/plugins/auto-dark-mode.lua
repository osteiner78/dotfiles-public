return {
  "f-person/auto-dark-mode.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    update_interval = 3000, -- Check every 3 seconds
    set_dark_mode = function()
      vim.api.nvim_set_option_value("background", "dark", {})
    end,
    set_light_mode = function()
      vim.api.nvim_set_option_value("background", "light", {})
    end,
  },
}
