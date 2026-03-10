return {
	-- Icons (Configured for performance and vibrancy)
	{
		"nvim-tree/nvim-web-devicons",
		lazy = true,
		opts = { color_icons = true },
	},

	-- Statusline
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			local lualine = require("lualine")
			local lazy_status = require("lazy.status")
			lualine.setup({
				options = {
					theme = "auto",
					ignore_focus = { "neo-tree" },
					globalstatus = true,
					component_separators = { left = "", right = "" },
					section_separators = { left = "", right = "" },
					disabled_filetypes = { statusline = {}, winbar = {} },
					always_divide_middle = true,
					refresh = { statusline = 1000, tabline = 1000, winbar = 1000 },
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { { "filename", path = 1 } },
					lualine_x = {
						{
							function() return "󰂚 " .. #require("snacks.notifier").get_history() end,
							cond = function() return package.loaded["snacks.notifier"] ~= nil and #require("snacks.notifier").get_history() > 0 end,
							color = { fg = "#fabd2f" },
						},
						{
							lazy_status.updates,
							cond = lazy_status.has_updates,
							color = { fg = "#ff9e64" },
						},
						{ "encoding" }, { "fileformat" }, { "filetype" },
					},
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
				inactive_sections = {
					lualine_a = {}, lualine_b = {}, lualine_c = { { "filename", path = 1 } },
					lualine_x = { "location" }, lualine_y = {}, lualine_z = {},
				},
			})
		end,
	},

	-- Bufferline (Tabs)
	{
		"akinsho/bufferline.nvim",
		version = "*",
		opts = {
			options = {
				separator_style = "slant",
				hover = { enabled = true, delay = 200, reveal = { "close" } },
				diagnostics = "nvim_lsp",
				offsets = {
					{ filetype = "neo-tree", text = "File Explorer", highlight = "Directory", separator = true },
				},
			},
		},
	},

	-- Autotag
	{
		"windwp/nvim-ts-autotag",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			opts = { enable_close = true, enable_rename = true, enable_close_on_slash = false },
			per_filetype = { ["html"] = { enable_close = true } }
		},
	},

    -- Render Markdown (Clean version)
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "Avante" },
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {},
    },
}
