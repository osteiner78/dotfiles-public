return {
  "folke/which-key.nvim",
  event = "VimEnter",
  opts = {
    preset = "modern",
    win = { border = "rounded" },
    icons = {
      breadcrumb = "»",
      separator = "➜",
      group = "+",
    },
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    wk.add({
      -- Top Level Groups
      { "<leader>f", group = "󰈔 [F]iles" },
      { "<leader>s", group = "󰈞 [S]earch" },
      { "<leader>c", group = "󰅱 [C]ode" },
      { "<leader>g", group = "󰊢 [G]it" },
      { "<leader>u", group = "󰙵 [U]I / Toggles" },
      { "<leader>w", group = "󰖲 [W]indows" },
      { "<leader>t", group = "󰓩 [T]abs" },
      { "<leader>b", group = "󰓩 [B]uffers" },
      { "<leader>d", group = "󰈙 [D]ocument" },
      { "<leader>x", group = "󰒡 [X] Trouble" },
      { "<leader>a", group = "󰚩 [A]I (Avante)" },
      { "<leader>q", group = "󰗼 [Q]uit / Session" },
      
      -- Moved clipboard maps hints
      { "<leader>D", desc = "Delete into clipboard", mode = {"n", "v"} },
      { "<leader>C", desc = "Change into clipboard", mode = {"n", "v"} },

      -- Git Sub-group [h]unks
      { "<leader>gh", group = "󰊢 [H]unks" },
      { "<leader>ghs", desc = "Stage hunk" },
      { "<leader>ghr", desc = "Reset hunk" },
      { "<leader>ghp", desc = "Preview hunk" },
      { "<leader>ghb", desc = "Blame line" },
      { "<leader>ght", desc = "Toggle blame" },
      { "<leader>ghd", desc = "Diff index" },
      { "<leader>ghD", desc = "Diff last commit" },
      { "<leader>ghx", desc = "Toggle deleted" },
      
      -- Surround (Sub-labels)
      { "gz", group = "󰗄 Surround" },
      { "gza", desc = "Add surrounding" },
      { "gzd", desc = "Delete surrounding" },
      { "gzr", desc = "Replace surrounding" },
      { "gzf", desc = "Find surrounding" },
      { "gzF", desc = "Find left surrounding" },
      
      -- Native Vim Hints
      { "z", group = "󰘖 Fold / UI" },
      { "\"", group = "󰅪 Registers" },
      { "g", group = "󰒕 Goto / Nav" },
      
      -- Standard Navigation
      { "gd", desc = "Definition" },
      { "gr", desc = "References" },
      { "gI", desc = "Implementation" },
      { "K", desc = "Hover" },
      { "]]", desc = "Next Ref" },
      { "[[", desc = "Prev Ref" },
    })
  end,
}
