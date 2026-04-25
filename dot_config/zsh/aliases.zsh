# Sourced by ~/.zshrc.
# Aliases that work the same on Mac and Linux. OS-specific aliases
# (clipboard helpers, etc.) live in ~/.zshrc itself (templated), not here.

# ---------------------------------------------------------------------------
# zellij — launch with custom AI coding layout
# ---------------------------------------------------------------------------

alias ai-cli='zellij --layout ai-coding'

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

# Prevent zsh autocorrect from mangling 1Password CLI commands
alias op="nocorrect op"

# Reload shell to pick up config changes
alias reload!='exec zsh'

# ---------------------------------------------------------------------------
# Filesystem (eza — modern ls; mirrors omarchy's defaults)
# ---------------------------------------------------------------------------

alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias la='eza -lah --group-directories-first --icons=auto'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'

# Quick parent-directory hops
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ---------------------------------------------------------------------------
# Tool shortcuts
# ---------------------------------------------------------------------------

alias g='git'
alias d='docker'
alias t='tmux attach || tmux new -s Work'

# Clear screen + Claude Code
alias cx='printf "\033[2J\033[3J\033[H" && claude'

# nvim — open current dir if no args, else open the args
n() {
    if [ "$#" -eq 0 ]; then
        command nvim .
    else
        command nvim "$@"
    fi
}

# ---------------------------------------------------------------------------
# Git shortcuts (commits, beyond what's in ~/.config/git/config aliases)
# ---------------------------------------------------------------------------

alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# ---------------------------------------------------------------------------
# Smart cd: zoxide takes over when arg isn't a real path
# Bare `cd` and `cd <real-dir>` work as before; `cd <fuzzy>` uses zoxide
# ---------------------------------------------------------------------------

if command -v zoxide &>/dev/null; then
    alias cd="zd"
    zd() {
        if (( $# == 0 )); then
            builtin cd ~ || return
        elif [[ -d $1 ]]; then
            builtin cd "$1" || return
        else
            if ! z "$@"; then
                echo "Error: Directory not found"
                return 1
            fi
            printf "\U000F17A9 "
            pwd
        fi
    }
fi

# ---------------------------------------------------------------------------
# Fuzzy file picker shortcuts (uses fzf + bat for preview)
# ---------------------------------------------------------------------------

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias eff='$EDITOR "$(ff)"'

# scp a fuzzy-picked file to a destination, e.g. `sff host:/tmp/`
sff() {
    if [ $# -eq 0 ]; then
        echo "Usage: sff <destination> (e.g. sff host:/tmp/)"
        return 1
    fi
    local file
    file=$(ff) && [ -n "$file" ] && scp "$file" "$1"
}
