# Sourced by ~/.zshrc.
# Aliases that work the same on Mac and Linux. OS-specific aliases live in
# ~/.zshrc itself (templated), not here.

# zellij — launch with custom AI coding layout
alias ai-cli='zellij --layout ai-coding'

# Prevent zsh autocorrect from mangling 1Password CLI commands
alias op="nocorrect op"

# Reload shell to pick up config changes
alias reload!='exec zsh'

# Saving keystrokes
alias g='git'

# eza — modern ls replacement (matches Omarchy default)
alias ls='eza -lh --group-directories-first --icons=auto'
alias la='eza -lah --group-directories-first --icons=auto'
alias lt='eza --tree --icons=auto'
