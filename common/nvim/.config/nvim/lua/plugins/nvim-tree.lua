return {
	"nvim-tree/nvim-tree.lua",
	lazy = true,
	cmd = { "NvimTreeToggle", "NvimTreeFocus" },
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local nvimtree = require("nvim-tree")

		-- recommended settings from nvim-tree documentation
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1

		nvimtree.setup({
			disable_netrw = true,
			hijack_cursor = true,
			sync_root_with_cwd = true,
			update_focused_file = {
				enable = true,
				update_root = false,
			},
			view = {
				width = 35,
				relativenumber = false,
				float = {
					-- enable = true,
				},
			},
			renderer = {
				highlight_git = true,
				indent_markers = {
					enable = true,
				},
				icons = {
					show = {
						file = true,
						folder = true,
						folder_arrow = true,
						git = true,
					},
					glyphs = {
						default = "󰈚",
						symlink = "",
						folder = {
							default = "",
							empty = "",
							empty_open = "",
							open = "",
							symlink = "",
							symlink_open = "",
							arrow_open = "",
							arrow_closed = "",
						},
						git = {
							unstaged = "✗",
							staged = "✓",
							unmerged = "",
							renamed = "➜",
							untracked = "★",
							deleted = "",
							ignored = "◌",
						},
					},
				},
			},
			-- change folder arrow icons
			-- renderer = {
			-- 	indent_markers = {
			-- 		enable = true,
			-- 	},
			-- 	icons = {
			-- 		glyphs = {
			-- 			folder = {
			-- 				arrow_closed = "", -- arrow when folder is closed
			-- 				arrow_open = "", -- arrow when folder is open
			-- 			},
			-- 		},
			-- 	},
			-- },
			-- disable window_picker for
			-- explorer to work well with
			-- window splits
			-- actions = {
			-- 	open_file = {
			-- 		window_picker = {
			-- 			enable = false,
			-- 		},
			-- 	},
			-- },
			filters = {
				custom = { ".DS_Store" },
			},
			git = {
				ignore = false,
			},
		})

		-- keymaps set in global keymaps.lua since this module is lazy loaded
	end,
}
