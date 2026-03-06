return {
	-- Collection of various small independent plugins/modules
	"echasnovski/mini.nvim",
	config = function()
		-- Better Around/Inside textobjects
		require("mini.ai").setup({ n_lines = 500 })

		-- Add/delete/replace surroundings (brackets, quotes, etc.)
		require("mini.surround").setup({
			mappings = {
				add = "gza",
				delete = "gzd",
				find = "gzf",
				find_left = "gzF",
				highlight = "gzh",
				replace = "gzr",
				update_n_lines = "gzn",
			},
		})

		-- Simple autopairs
		require("mini.pairs").setup()

		-- Simple commenting
		require("mini.comment").setup()

		-- Move blocks of code
		require("mini.move").setup()

		-- Minimap with integration
		local minimap = require("mini.map")
		minimap.setup({
			integrations = {
				minimap.gen_integration.builtin_search(),
				minimap.gen_integration.diff(),
				minimap.gen_integration.diagnostic(),
			},
			symbols = { encode = minimap.gen_encode_symbols.dot("4x2") },
			window = { side = "right", width = 20, winblend = 15 },
		})
	end,
}
