return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false, -- always track latest commit
  opts = {
    provider = "gemini",
    auto_suggestions_provider = "gemini",
    -- Gemini Configuration
    providers = {
      gemini = {
        model = "gemini-2.0-flash",
        max_tokens = 8192,
        temperature = 0,
      },
    },
    behaviour = {
      auto_suggestions = false, -- Change to true if you want ghost text
      auto_set_highlight_group = true,
      auto_set_keymaps = true,
      auto_apply_diff_after_generation = false,
      support_paste_from_clipboard = false,
    },
    mappings = {
      --- @class AvanteConflictMappings
      diff = {
        ours = "co",
        theirs = "ct",
        all_theirs = "ca",
        both = "cb",
        cursor = "cc",
        next = "]x",
        prev = "[x",
      },
      suggestion = {
        accept = "<M-l>",
        next = "<M-]>",
        prev = "<M-[>",
        dismiss = "<C-]>",
      },
      jump = {
        next = "]a",
        prev = "[a",
      },
      submit = {
        normal = "<CR>",
        insert = "<C-s>",
      },
    },
  },
  build = "make",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
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
        },
      },
    },
  },
}
