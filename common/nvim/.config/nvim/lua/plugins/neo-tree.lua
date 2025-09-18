-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
    {
	"nvim-neo-tree/neo-tree.nvim",
	enabled = true,
	version = "*",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
	},
	cmd = "Neotree",
	keys = {
		{ "\\", ":Neotree reveal<CR>", { desc = "NeoTree reveal" } },
	},
	opts = {
		filesystem = {
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
  -- highlight overrides
      default_component_configs = {
        name = {
          highlight_opened_files = "all", -- optional
          use_git_status_colors = true,   -- optional
        },
      },
      },
      config = function(_, opts)
        require("neo-tree").setup(opts)

        -- override highlights so dot/hidden files don't get "dimmed"
        vim.cmd([[
          hi! link NeoTreeDotfile NeoTreeFileName
          hi! link NeoTreeHiddenByName NeoTreeFileName
          hi! link NeoTreeGitIgnored NeoTreeFileName
        ]])
      end,
	},
  {
    "antosha417/nvim-lsp-file-operations",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neo-tree/neo-tree.nvim", -- makes sure that this loads after Neo-tree.
    },
    config = function()
      require("lsp-file-operations").setup()
    end,
  },
  {
    "s1n7ax/nvim-window-picker",
    version = "2.*",
    config = function()
      require("window-picker").setup({
        filter_rules = {
          include_current_win = false,
          autoselect_one = true,
          -- filter using buffer options
          bo = {
            -- if the file type is one of following, the window will be ignored
            filetype = { "neo-tree", "neo-tree-popup", "notify" },
            -- if the buffer type is one of following, the window will be ignored
            buftype = { "terminal", "quickfix" },
          },
        },
      })
    end,
  },
}
