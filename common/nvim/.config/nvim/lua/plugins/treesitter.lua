return {
	{ -- Highlight, edit, and navigate code
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		lazy = false,
		priority = 1000,
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
			"nvim-treesitter/nvim-treesitter-context",
		},
		opts = {
			ensure_installed = {
				"bash", "c", "diff", "html", "lua", "luadoc", "markdown", "markdown_inline",
				"vim", "vimdoc", "regex", "query", "css", "javascript", "typescript", "tsx", 
                "json", "python", "yaml",
			},
			sync_install = false,
			auto_install = true,
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = true, -- fallback when treesitter parser is missing
			},
			indent = { enable = true },
			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
					},
				},
				move = {
					enable = true,
					set_jumps = true,
					goto_next_start = { ["]m"] = "@function.outer", ["]C"] = "@class.outer" },
					goto_next_end = { ["]M"] = "@function.outer", ["]["] = "@class.outer" },
					goto_previous_start = { ["[m"] = "@function.outer", ["[C"] = "@class.outer" },
					goto_previous_end = { ["[M"] = "@function.outer", ["[]"] = "@class.outer" },
				},
				swap = {
					enable = true,
					swap_next = { ["<leader>cp"] = "@parameter.inner" },
					swap_previous = { ["<leader>cP"] = "@parameter.inner" },
				},
			},
		},
		config = function(_, opts)
			require("nvim-treesitter.install").prefer_git = true
			local ok, mod = pcall(require, "nvim-treesitter.configs")
			if not ok then mod = require("nvim-treesitter.config") end
			mod.setup(opts)

			require("treesitter-context").setup({
				enable = true,
				max_lines = 3,
				line_numbers = true,
			})
		end,
	},
}
