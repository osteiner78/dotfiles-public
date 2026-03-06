return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile =       { enabled = true },
    dashboard =     { 
      enabled = true,
      sections = {
        { section = "header" },
        { section = "keys", gap = 1 },
        { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = { 2, 2 } },
        { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 2 },
        { section = "startup" },
      },
    },
    explorer =      { enabled = false }, -- Using Neo-tree
    indent =        { 
      enabled = true,
      scope = {
        enabled = true,
        underline = true,
      }
    },
    input =         { enabled = true },
    picker =        { enabled = true },
    notifier =      { enabled = true },
    quickfile =     { enabled = true },
    scope =         { enabled = true },
    scroll =        { enabled = true },
    statuscolumn =  { enabled = true },
    words =         { enabled = true },
    rename =        { enabled = true },
    profiler =      { enabled = true },
    win =           { enabled = true },
  },
  keys = {
    -- Top Pickers
    { "<leader><leader>", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
    
    -- Files (Mnemonic: [F]iles)
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
    { "<leader>fn", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Neovim Config" },
    { "<leader>fa", function() Snacks.picker.files({ hidden = true, ignored = true }) end, desc = "Find All Files" },
    { "<leader>fR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
    
    -- Search (Mnemonic: [S]earch)
    { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "n", "x" } },
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Tags" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo History" },
    { "<leader>ss", function() Snacks.picker.resume() end, desc = "Resume Last Search" },
    
    -- Git (Mnemonic: [G]it)
    { "<leader>gc", function() Snacks.picker.git_log() end, desc = "Git Log" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
    { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
    
    -- UI / Toggles (Mnemonic: [U]I)
    { "<leader>ut", function() Snacks.picker.colorschemes() end, desc = "Themes" },
    { "<leader>un", function() Snacks.notifier.show_history() end, desc = "Notification History" },
    
    -- Buffers (Mnemonic: [B]uffers)
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
    { "<leader>bo", function() Snacks.bufdelete.other() end, desc = "Delete Other Buffers" },
    { "<leader>bD", function() Snacks.bufdelete.all() end, desc = "Delete All Buffers" },
  },
}
