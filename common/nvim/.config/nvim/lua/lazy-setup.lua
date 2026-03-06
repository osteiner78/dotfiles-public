local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{ import = "plugins" },
}, {
	rocks = { enabled = false },
	checker = { enabled = true, notify = false },
	change_detection = { notify = true },
	ui = {
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘", config = "🛠", event = "📅", ft = "📂", init = "⚙",
			keys = "🗝", plugin = "🔌", runtime = "💻", require = "🌙",
			source = "📄", start = "🚀", task = "📌", lazy = "💤 ",
		},
	},
})
