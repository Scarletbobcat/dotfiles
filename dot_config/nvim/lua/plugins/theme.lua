-- Sets LazyVim's active colorscheme.
-- On Mac: chezmoi writes this static file (everforest).
-- On Linux/Omarchy: chezmoi ignores this path (.chezmoiignore) so omarchy's
-- dynamic symlink to ~/.config/omarchy/current/theme/neovim.lua stays in charge.
return {
	{ "neanias/everforest-nvim" },
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "everforest",
			background = "soft",
		},
	},
}
