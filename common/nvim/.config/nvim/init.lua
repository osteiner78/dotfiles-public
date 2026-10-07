vim.cmd([[
  filetype plugin indent on
  syntax enable
]])

-- Prepend nvm's active node bin to PATH so spawned processes can find node tools
do
  local nvm_dir = vim.fn.expand("~/.nvm")
  local alias_file = io.open(nvm_dir .. "/alias/default", "r")
  if alias_file then
    local alias = alias_file:read("*l"):gsub("%s+", "")
    alias_file:close()
    -- alias may be "22", "v22.17.0", or an lts name — normalise to a glob prefix
    local prefix = alias:match("^v?(%d+)") or alias
    local matches = vim.fn.glob(nvm_dir .. "/versions/node/v" .. prefix .. "*/bin", false, true)
    if #matches > 0 then
      -- take the last entry (highest patch version)
      vim.env.PATH = matches[#matches] .. ":" .. vim.env.PATH
    end
  end
end

-- Filetype detection rules
vim.filetype.add({
	extension = {
		hypr = "hyprlang",
	},
	filename = {
		["hyprland.conf"] = "hyprlang",
		["hyprland.hypr"] = "hyprlang",
		["hypridle.conf"] = "hyprlang",
	},
})

require("options")
require("lazy-setup")
require("keymaps")

-- Highlight when yanking
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- vim: ts=4 sts=4 sw=4 et
