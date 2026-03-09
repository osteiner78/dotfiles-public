return {
	"folke/which-key.nvim",
	event = "VimEnter",
	opts = {
		preset = "modern",
		win = { border = "rounded" },
		icons = {
			breadcrumb = "»",
			separator = "➜",
			group = "+",
		},
	},
	config = function(_, opts)
		local wk = require("which-key")
		wk.setup(opts)

		wk.add({
			-- Top Level Group Labels
			{ "<leader>f", group = "󰈔 [F]iles" },
			{ "<leader>s", group = "󰈞 [S]earch" },
			{ "<leader>c", group = "󰅱 [C]ode" },
			{ "<leader>g", group = "󰊢 [G]it" },
			{ "<leader>u", group = "󰙵 [U]I / Toggles" },
			{ "<leader>w", group = "󰖲 [W]indows" },
			{ "<leader>t", group = "󰓩 [T]abs" },
			{ "<leader>b", group = "󱡃 [B]uffers" },
			{ "<leader>x", group = "󰒡 [X] Trouble" },
			{ "<leader>a", group = "󰚩 [A]I (Avante)" },
			{ "<leader>q", group = "󰗼 [Q]uit / Session" },

			-- Clipboard delete/change fallbacks (black-hole remaps in keymaps.lua)
			{ "<leader>D", desc = "Delete into Clipboard" },
			{ "<leader>C", desc = "Change into Clipboard" },

			-- Git Sub-group: hunks
			{ "<leader>gh",  group = "󰊢 [H]unks" },

			-- Surround (Sub-labels for better visibility)
			{ "gz",  group = "󰗄 Surround" },
			{ "gza", desc = "Add Surrounding" },
			{ "gzd", desc = "Delete Surrounding" },
			{ "gzr", desc = "Replace Surrounding" },
			{ "gzf", desc = "Find Surrounding (right)" },
			{ "gzF", desc = "Find Surrounding (left)" },
			{ "gzh", desc = "Highlight Surrounding" },
			{ "gzn", desc = "Update n_lines" },

			-- Treesitter: swap parameters (not auto-picked, defined in textobjects spec)
			{ "<leader>cp", desc = "Swap Next Parameter" },
			{ "<leader>cP", desc = "Swap Prev Parameter" },

			-- Native Vim Groups
			{ "z",  group = "󰘖 Fold / UI" },
			{ "\"", group = "󰅪 Registers" },
			{ "g",  group = "󰒕 Goto / Nav" },
		})
	end,
}
