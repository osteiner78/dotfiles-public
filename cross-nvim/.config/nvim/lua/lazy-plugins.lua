require("lazy").setup({
	{ import = "plugins" }, -- Imports all plugins in lua/oliver/plugins
}, { -- options - https://github.com/folke/lazy.nvim?tab=readme-ov-file#-installation
	checker = {
		enabled = true,
		notify = true,
	},
	change_detection = {
		notify = true,
	},
	ui = {
		-- If you are using a Nerd Font: set icons to an empty table which will use the
		-- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘",
			config = "🛠",
			event = "📅",
			ft = "📂",
			init = "⚙",
			keys = "🗝",
			plugin = "🔌",
			runtime = "💻",
			require = "🌙",
			source = "📄",
			start = "🚀",
			task = "📌",
			lazy = "💤 ",
		},
	},
})
