-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- General settings
vim.opt.hlsearch = true -- Set highlight on search

-- [[ Basic Mappings ]]
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })
vim.keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode" })
vim.keymap.set("n", ";", ":", { desc = "Enter command mode" })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

--- Buffer Management
vim.keymap.set("n", "<tab>", "<cmd>bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<s-tab>", "<cmd>bprevious<CR>", { desc = "Next buffer" })

-- Window Management
vim.keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Split [w]indow [v]ertically" })
vim.keymap.set("n", "<leader>wh", "<C-w>s", { desc = "Split [w]indow [h]orizontally" })
vim.keymap.set("n", "<leader>we", "<C-w>=", { desc = "Make splits [e]qual size" })
vim.keymap.set("n", "<leader>wx", "<cmd>close<CR>", { desc = "Close current split" })

-- Tab Management
vim.keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
vim.keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
vim.keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
vim.keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
vim.keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffe in new tab" })

-- Utils
vim.keymap.set("n", "<leader>ln", "<cmd>set nu!<CR>", { desc = "toggle [l]ine [n]umber" })
vim.keymap.set("n", "<leader>rn", "<cmd>set rnu!<CR>", { desc = "toggle [r]elative [n]umber" })
vim.keymap.set("n", "<leader>ch", "<cmd>Telescope keymaps<CR>", { desc = "toggle cheatsheet" })

-- Comment
vim.keymap.set("n", "<leader>/", "gcc", { desc = "comment toggle", remap = true })
vim.keymap.set("v", "<leader>/", "gc", { desc = "comment toggle", remap = true })

-- nvimtree
vim.keymap.set("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle window" })
-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous [D]iagnostic message" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next [D]iagnostic message" })
vim.keymap.set("n", "<leader>de", vim.diagnostic.open_float, { desc = "Show [d]iagnostic [e]rror messages" })
vim.keymap.set("n", "<leader>dq", vim.diagnostic.setloclist, { desc = "Open [d]iagnostic [q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- ======================================== ARCHIVE ==========================================
-- increment/decrement numbers
-- vim.keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')
-- vim.keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement
