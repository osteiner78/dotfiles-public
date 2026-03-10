vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- [[ Editor Options ]]
vim.g.have_nerd_font = true
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.mouse = "a"
vim.opt.showmode = false

-- Sync clipboard
vim.opt.clipboard = "unnamedplus"
if vim.fn.has("wsl") == 1 then
	vim.g.clipboard = {
		name = "WslClipboard",
		copy = { ["+"] = "clip.exe", ["*"] = "clip.exe" },
		paste = {
			["+"] = "powershell.exe -NoLogo -NoProfile -Command Get-Clipboard",
			["*"] = "powershell.exe -NoLogo -NoProfile -Command Get-Clipboard",
		},
		cache_enabled = 0,
	}
elseif vim.env.WAYLAND_DISPLAY then
	vim.g.clipboard = {
		name = "wl-copy",
		copy = { ["+"] = "wl-copy", ["*"] = "wl-copy" },
		paste = { ["+"] = { "wl-paste", "--no-newline" }, ["*"] = { "wl-paste", "--no-newline" } },
		cache_enabled = 1,
	}
end

-- Appearance & Behavior
vim.opt.hlsearch = true
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.inccommand = "split"
vim.opt.cursorline = true
vim.opt.cursorlineopt = "both"
vim.opt.scrolloff = 10
vim.opt.conceallevel = 2
vim.opt.concealcursor = "nc"

-- Tabs & Indentation
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Undo Persistence
local undodir = vim.fn.stdpath("data") .. "/undo"
vim.fn.mkdir(undodir, "p")
vim.opt.undodir = undodir

-- Providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0

-- Diagnostic Configuration (Icons + Defaults)
vim.diagnostic.config({
	virtual_text = false, -- Disable virtual text by default
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = " ",
			[vim.diagnostic.severity.WARN]  = " ",
			[vim.diagnostic.severity.HINT]  = "󰠠 ",
			[vim.diagnostic.severity.INFO]  = " ",
		},
	},
})

-- Disable diagnostics engine by default on startup
vim.diagnostic.enable(false)
