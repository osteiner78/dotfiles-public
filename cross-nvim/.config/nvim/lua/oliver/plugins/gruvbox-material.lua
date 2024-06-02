return {
	"sainnhe/gruvbox-material",
	priority = 1000,
	lazy = true,
	config = true,
	-- opts = ...,
	config = function()
		-- Optionally configure and load the colorscheme
		-- directly inside the plugin declaration.
		vim.g.gruvbox_material_enable_italic = true
		-- vim.cmd.colorscheme('gruvbox-material')
	end,
	-- init =function()
	-- vim.cmd.colorscheme("gruvbox")
}
