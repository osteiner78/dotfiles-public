return {
	-- Git Signs
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
			on_attach = function(bufnr)
				local gs = require("gitsigns")
				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					vim.keymap.set(mode, l, r, opts)
				end

				-- which-key hints for buffer-local gitsigns keymaps
				require("which-key").add({
					{ "<leader>ghs", desc = "Stage Hunk",       buffer = bufnr },
					{ "<leader>ghr", desc = "Reset Hunk",       buffer = bufnr },
					{ "<leader>ghS", desc = "Stage Buffer",     buffer = bufnr },
					{ "<leader>ghu", desc = "Undo Stage Hunk",  buffer = bufnr },
					{ "<leader>ghR", desc = "Reset Buffer",     buffer = bufnr },
					{ "<leader>ghp", desc = "Preview Hunk",     buffer = bufnr },
					{ "<leader>ghb", desc = "Blame Line",       buffer = bufnr },
					{ "<leader>ght", desc = "Toggle Blame",     buffer = bufnr },
					{ "<leader>ghd", desc = "Diff Index",       buffer = bufnr },
					{ "<leader>ghD", desc = "Diff Last Commit", buffer = bufnr },
					{ "<leader>ghx", desc = "Toggle Deleted",   buffer = bufnr },
				})

				-- Navigation
				map("n", "]c", function()
					if vim.wo.diff then return "]c" end
					vim.schedule(function() gs.next_hunk() end)
					return "<Ignore>"
				end, { expr = true, desc = "Next Hunk" })

				map("n", "[c", function()
					if vim.wo.diff then return "[c" end
					vim.schedule(function() gs.prev_hunk() end)
					return "<Ignore>"
				end, { expr = true, desc = "Prev Hunk" })

				-- Actions (Mnemonic: [g]it [h]unk)
				map("n", "<leader>ghs", gs.stage_hunk, { desc = "Stage Hunk" })
				map("n", "<leader>ghr", gs.reset_hunk, { desc = "Reset Hunk" })
				map("v", "<leader>ghs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Stage Hunk" })
				map("v", "<leader>ghr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Reset Hunk" })
				map("n", "<leader>ghS", gs.stage_buffer, { desc = "Stage Buffer" })
				map("n", "<leader>ghu", gs.undo_stage_hunk, { desc = "Undo Stage Hunk" })
				map("n", "<leader>ghR", gs.reset_buffer, { desc = "Reset Buffer" })
				map("n", "<leader>ghp", gs.preview_hunk, { desc = "Preview Hunk" })
				map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, { desc = "Blame Line" })
				map("n", "<leader>ght", gs.toggle_current_line_blame, { desc = "Toggle Blame" })
				map("n", "<leader>ghd", gs.diffthis, { desc = "Diff Index" })
				map("n", "<leader>ghD", function() gs.diffthis("~") end, { desc = "Diff Last Commit" })
				map("n", "<leader>ghx", gs.toggle_deleted, { desc = "Toggle Deleted" })

				-- Text object
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select Hunk" })
			end,
		},
	},

	-- Diffview
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose" },
		keys = {
			{ "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
			{ "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "File History" },
		},
	},
}
