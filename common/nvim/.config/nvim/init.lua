vim.cmd([[
  filetype plugin indent on
  syntax enable
]])

-- Filetype detection rules
vim.filetype.add({
	extension = {
		hypr = "hyprlang",
		conf = "hyprlang",
        md = "markdown",
        markdown = "markdown",
	},
	filename = {
		["hyprland.conf"] = "hyprlang",
		["hyprland.hypr"] = "hyprlang",
		["hypridle.conf"] = "hyprlang",
	},
})

require("options")
require("keymaps")
require("lazy-setup")

-- Highlight when yanking
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- vim: ts=4 sts=4 sw=4 et
