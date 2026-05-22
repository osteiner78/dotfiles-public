return {
  "rebelot/kanagawa.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    -- example config
    compile = false,
    undercurl = true,
    commentStyle = { italic = true },
    functionStyle = {},
    keywordStyle = { italic = true },
    statementStyle = { bold = true },
    typeStyle = {},
    transparent = false,
    dimInactive = false,
    terminalColors = true,
    colors = { theme = { all = { ui = { bg_gutter = "none" } } } },
    theme = "wave", -- "wave", "dragon", "lotus"
  },
}
