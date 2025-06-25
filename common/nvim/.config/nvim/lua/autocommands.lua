vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_augroup("MyGroup", { clear = true })

-- reload config file on change
vim.api.nvim_create_autocmd("BufWritePost", {
	group = "MyGroup",
	pattern = vim.env.MYVIMRC,
	command = "silent source %",
})
