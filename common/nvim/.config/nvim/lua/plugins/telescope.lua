return {
	-- Fuzzy Finder (files, lsp, etc)
	"nvim-telescope/telescope.nvim",
	event = "VimEnter",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ -- If encountering errors, see telescope-fzf-native README for installation instructions
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
			cond = function()
				return vim.fn.executable("make") == 1
			end,
		},
		{ "nvim-telescope/telescope-ui-select.nvim" },
		{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")
		local transform_mod = require("telescope.actions.mt").transform_mod
		-- local trouble = require("trouble")
		-- local trouble_telescope = require("trouble.sources.telescope")

		local custom_actions = transform_mod({
			open_trouble_qflist = function(prompt_bufnr)
				trouble.toggle("quickfix")
			end,
		})

		telescope.setup({
			pickers = {
				colorscheme = { enable_preview = true },
			},
			path_display = { "smart" },
			mappings = {
				i = {
					["<C-k>"] = actions.move_selection_previous,
					["<C-j>"] = actions.move_selection_next,
					["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
					-- ["<C-t>"] = trouble_telescope.open,
				},
			},
			extensions = {
				["ui-select"] = {
					require("telescope.themes").get_dropdown(),
				},
			},
		})

		pcall(telescope.load_extension, "fzf")
		pcall(telescope.load_extension, "ui-select")

		local builtin = require("telescope.builtin")

		vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "[F]ind existing [b]uffers" })
		vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "[F]ind [h]elp" })
		vim.keymap.set("n", "<leader>fm", builtin.marks, { desc = "[F]ind [m]arks" })
		-- vim.keymap.set("n", "<leader>fgc", builtin.git_commits, { desc = "[F]ind [g]it [c]ommits" })
		-- vim.keymap.set("n", "<leader>fgs", builtin.git_status, { desc = "[F]ind [g]it [s]tatus" })
		vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "[F]ind [t]odos" })
		vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "[F]ind [k]eymaps" })
		vim.keymap.set("n", "<leader>fT", builtin.builtin, { desc = "[F]ind Select [t]elescope" })
		vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "[F]ind [d]iagnostics" })
		vim.keymap.set("n", "<leader>fR", builtin.resume, { desc = "[F]ind [r]esume" })
		vim.keymap.set("n", "<leader>th", builtin.colorscheme, { desc = "Find [th]eme" })

        -- FIND FILES
		-- vim.keymap.set("n", "<leader>ffa", "<cmd>Telescope find_files follow=true no_ignore=true<CR>", { desc = "[F]ind [a]ll [f]iles in cwd" })
		-- Find files
		vim.keymap.set("n", "<leader>ffa", function()
			builtin.find_files({
            hidden = true,       -- include dotfiles
            follow = true,       -- follow symlinks
            })

		end, { desc = "[F]ind [f]iles - [A]ll in cwd" })

		--  Recent files
		vim.keymap.set("n", "<leader>ffr", builtin.oldfiles, { desc = "[F]ind [f]iles - [R]ecent" })

		--  Files in ~/.config
        vim.keymap.set("n", "<leader>ffc", function()
          require("telescope.builtin").find_files({
            cwd = "~/.config",
            hidden = true,       -- include dotfiles
            follow = true,       -- follow symlinks
          })
        end, { desc = "[F]ind [f]iles - ~/.[c]onfig" })

		-- Neovim config files
		vim.keymap.set("n", "<leader>ffn", function()
			builtin.find_files({ cwd = vim.fn.stdpath("config") })
		end, { desc = "[F]ind [f]iles - [N]eovim" })


        -- ====================== LIVE GREP =================================
		-- .config, excluding uninteresting folders
		vim.keymap.set("n", "<leader>fgc", function()
			builtin.live_grep({
				cwd = vim.fn.expand("~/.config"),
				prompt_title = "[F]ind [g]rep - ~/.[c]onfig",
				additional_args = function()
					return {
						"--hidden", -- include hidden file[l]s
						"--follow", -- follow symlinks
                        "--glob", "!Code/**",      -- exclude VSCode configs
						"--glob", "!.history/**",
						"--glob", "!.git/**", -- skip git dirs (optional)
					}
				end,
			}) end, { desc = "[F]ind [g]rep - ~/.[c]onfig" })

		vim.keymap.set("n", "<leader>fga", builtin.live_grep, { desc = "[F]ind [g]rep - [A]ll in cwd" })

		-- Grep only in open files
		vim.keymap.set("n", "<leader>fgo", function()
			builtin.live_grep({
				grep_open_files = true,
				prompt_title = "Live Grep in Open Files",
			})
		end, { desc = "[F]ind [g]rep - [O]pen files" })

		-- vim.keymap.set("n", "<leader>fz", function()
		-- 	builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		-- 		winblend = 10,
		-- 		previewer = false,
		-- 	}))
		-- end, { desc = "[/] Fuzzily search in current buffer" })

	end,
}
