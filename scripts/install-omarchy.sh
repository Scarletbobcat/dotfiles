#!/usr/bin/env bash
# Bootstrap a fresh Omarchy/Arch machine. Idempotent: safe to re-run.
# Uses yay (the AUR helper that ships with Omarchy) so it can install
# from both official repos and the AUR with a single command.
# Usage:  ./scripts/install-omarchy.sh

set -euo pipefail

if ! command -v yay &>/dev/null; then
    echo "yay not installed. Install it first or use a base Omarchy image."
    echo "  sudo pacman -S --needed git base-devel"
    echo "  git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si"
    exit 1
fi

PACKAGES=(
    # Shell + plugins
    zsh
    starship
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    zsh-fzf-tab-git    # AUR
    zoxide
    fzf

    # Modern CLI tools
    eza

    # Terminal multiplexers
    tmux
    zellij

    # Dev tooling
    mise-bin           # AUR
    github-cli
    git

    # Editors
    neovim

    # Terminal emulator
    ghostty
)

echo "Installing packages via yay..."
yay -S --needed --noconfirm "${PACKAGES[@]}"

# Make zsh the default shell if it isn't already
if [[ "$SHELL" != *"zsh"* ]]; then
    echo
    echo "Setting zsh as default shell. You'll be prompted for your password."
    chsh -s "$(which zsh)"
    echo "Default shell changed. Log out and back in for it to take effect."
fi

echo
echo "Done. Next steps:"
echo "  1. Run 'chezmoi apply' to lay down configs"
echo "  2. Log out and back in (or run 'exec zsh') to pick up the new shell setup"
