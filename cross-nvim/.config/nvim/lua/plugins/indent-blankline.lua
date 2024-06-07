return {
	{ -- Add indentation guides even on blank lines
		"lukas-reineke/indent-blankline.nvim",
		-- Enable `lukas-reineke/indent-blankline.nvim`
		-- See `:help ibl`
		enabled = true,
		event = { "BufReadPost", "BufNewFile" },
		main = "ibl",
		opts = {
			indent = { char = "│" }, --, highlight = "IblChar" },
			scope = { char = "│" }, --highlight = "IblScopeChar" },
		},
	},
}
