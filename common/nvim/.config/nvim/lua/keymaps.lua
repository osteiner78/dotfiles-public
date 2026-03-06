
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
vim.keymap.set("n", ";", ":", { desc = "Use semicolon for commands" })

-- Clear search highlights
vim.opt.hlsearch = true
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- [[ Black Hole Register Mappings ]]
vim.keymap.set({"n", "v"}, "d", '"_d')
vim.keymap.set({"n", "v"}, "c", '"_c')
vim.keymap.set("n", "x", '"_x')

-- Special shortcuts if you DO want to delete and yank
-- Moved from <leader>d to <leader>D to avoid collision with Document group
vim.keymap.set({"n", "v"}, "<leader>D", "d", { desc = "Delete into clipboard" })
vim.keymap.set({"n", "v"}, "<leader>C", "c", { desc = "Change into clipboard" })

-- [[ Productivity: Centered Motion ]]
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search match and center" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev search match and center" })

-- [[ Window Navigation ]]
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- [[ Window Management ]]
vim.keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Split [V]ertical" })
vim.keymap.set("n", "<leader>wh", "<C-w>s", { desc = "Split [H]orizontal" })
vim.keymap.set("n", "<leader>we", "<C-w>=", { desc = "Make [E]qual" })
vim.keymap.set("n", "<leader>wx", "<cmd>close<CR>", { desc = "Close window" })

-- [[ Buffer Management ]]
vim.keymap.set("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })

-- [[ Tab Management ]]
vim.keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "[O]pen tab" })
vim.keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "[N]ext tab" })
vim.keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "[P]revious tab" })

-- [[ File Explorer (Neo-tree) ]]
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "Explorer" })
vim.keymap.set("n", "\\", "<cmd>Neotree toggle<CR>", { desc = "Explorer" })

-- [[ UI / Toggles (using Snacks.toggle) ]]
vim.keymap.set("n", "<leader>ul", function() Snacks.toggle.number():toggle() end, { desc = "Toggle [L]ine Numbers" })
vim.keymap.set("n", "<leader>ur", function() Snacks.toggle.option("relativenumber", { name = "Relative Number" }):toggle() end, { desc = "Toggle [R]elative Numbers" })
vim.keymap.set("n", "<leader>um", function() MiniMap.toggle() end, { desc = "Toggle [M]inimap" })
vim.keymap.set("n", "<leader>ud", function() Snacks.toggle.diagnostics():toggle() end, { desc = "Toggle [D]iagnostics" })
vim.keymap.set("n", "<leader>ub", function() Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):toggle() end, { desc = "Toggle [B]ackground" })

-- [[ Navigation ]]
vim.keymap.set("n", "]]", function() Snacks.words.jump(vim.v.count1) end, { desc = "Next Reference" })
vim.keymap.set("n", "[[", function() Snacks.words.jump(-vim.v.count1) end, { desc = "Prev Reference" })

-- Exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
