return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		cmd = "Neotree",
		keys = {
			{ "\\", ":Neotree reveal<CR>", desc = "NeoTree Reveal" },
		},
		opts = {
			filesystem = {
				hijack_netrw_behavior = "open_default",
				filtered_items = {
					visible = true,
					hide_dotfiles = false,
					hide_gitignored = false,
				},
				window = {
					mappings = {
						["\\"] = "close_window",
					},
				},
			},
			default_component_configs = {
				name = {
					highlight_opened_files = "all",
					use_git_status_colors = true,
				},
			},
		},
		config = function(_, opts)
			require("neo-tree").setup(opts)
			vim.cmd([[
				hi! link NeoTreeDotfile NeoTreeFileName
				hi! link NeoTreeHiddenByName NeoTreeFileName
				hi! link NeoTreeGitIgnored NeoTreeFileName
			]])
		end,
	},
	{
		"antosha417/nvim-lsp-file-operations",
		dependencies = { "nvim-lua/plenary.nvim", "nvim-neo-tree/neo-tree.nvim" },
		config = function() require("lsp-file-operations").setup() end,
	},
	{
		"s1n7ax/nvim-window-picker",
		version = "2.*",
		config = function()
			require("window-picker").setup({
				filter_rules = {
					include_current_win = false,
					autoselect_one = true,
					bo = {
						filetype = { "neo-tree", "neo-tree-popup", "notify" },
						buftype = { "terminal", "quickfix" },
					},
				},
			})
		end,
	},
}
