vim.keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- Clear search highlights
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- [[ Black Hole Register Mappings ]]
-- vim.keymap.set({"n", "v"}, "d", '"_d')
-- vim.keymap.set({"n", "v"}, "c", '"_c')
-- vim.keymap.set("n", "x", '"_x')

-- Special shortcuts if you DO want to delete and yank
vim.keymap.set({ "n", "v" }, "<leader>D", "d", { desc = "Delete into clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>C", "c", { desc = "Change into clipboard" })

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

-- [[ Commenting ]]
-- Using direct call to mini.comment for reliability
vim.keymap.set("n", "<leader>/", function()
	require("mini.comment").toggle_lines(vim.fn.line("."), vim.fn.line("."))
end, { desc = "Comment line" })
vim.keymap.set("v", "<leader>/", function()
	require("mini.comment").toggle_lines(vim.fn.line("v"), vim.fn.line("."))
end, { desc = "Comment selection" })

-- [[ UI / Toggles (Official Snacks mapping method) ]]
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>ur")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")

-- Foolproof Minimap Toggle tracking
local minimap_active = false
Snacks.toggle
	.new({
		name = "Minimap",
		get = function()
			return minimap_active
		end,
		set = function(state)
			minimap_active = state
			MiniMap.toggle()
		end,
	})
	:map("<leader>um")

-- [[ Code ]]
vim.keymap.set("n", "<leader>cd", function()
	vim.diagnostic.enable()
	vim.diagnostic.open_float()
end, { desc = "Diagnostic Float" })

-- [[ Quit ]]
vim.keymap.set("n", "<leader>qq", "<cmd>qa<CR>", { desc = "Quit All" })

-- [[ Navigation ]]
vim.keymap.set("n", "]]", function()
	Snacks.words.jump(vim.v.count1)
end, { desc = "Next Reference" })
vim.keymap.set("n", "[[", function()
	Snacks.words.jump(-vim.v.count1)
end, { desc = "Prev Reference" })
vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { desc = "Previous Quickfix item" })
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { desc = "Next Quickfix item" })

-- Exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
