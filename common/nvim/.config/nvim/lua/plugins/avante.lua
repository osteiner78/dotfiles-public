return {
  "yetone/avante.nvim",
  build = vim.fn.has("win32") ~= 0
    and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
    or "make",
  event = "VeryLazy",
  version = false,
  ---@module 'avante'
  ---@type avante.Config
  opts = {
    provider = "opencode",
    acp_providers = {
      ["opencode"] = {
        command = vim.fn.exepath("opencode"),
        args = { "acp" },
      },
    },
    input = {
      provider = "snacks",
      provider_opts = {
        title = "Avante Input",
        icon = " ",
      },
    },
    behaviour = {
      auto_add_current_file = true,
      auto_approve_tool_permissions = true,
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "hrsh7th/nvim-cmp",
    "nvim-tree/nvim-web-devicons",
    "folke/snacks.nvim",
    {
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          use_absolute_path = true,
        },
      },
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      ft = { "markdown", "Avante" },
      opts = {
        file_types = { "markdown", "Avante" },
      },
    },
  },
}