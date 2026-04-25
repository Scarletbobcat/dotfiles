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
    jq                 # required by jackknife setup.sh
    lazygit
    lazydocker         # talks to Docker daemon already provided by Omarchy

    # Editors
    neovim

    # Terminal emulator
    ghostty

    # Multi-agent workflow stack
    ntm                # AUR or upstream
    bv-bin             # AUR (beads viewer)
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
echo "Installing Node via mise (provides runtime for npm-installed CLIs)..."
mise use -g node@latest

echo
echo "Installing global npm CLIs (Claude Code, Codex)..."
npm install -g @anthropic-ai/claude-code @openai/codex

echo
echo "Installing jackknife stack (beads CLI + agent mail)..."
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh?$(date +%s)" | bash
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail_rust/main/install.sh?$(date +%s)" | bash

echo
echo "Done. Next steps:"
echo "  1. Run 'chezmoi apply' to lay down configs"
echo "  2. Log out and back in (or run 'exec zsh') to pick up the new shell setup"
echo "  3. (Optional) Install Compound Engineering plugin from inside Claude Code:"
echo "     /plugin marketplace add EveryInc/compound-engineering-plugin"
echo "     /plugin install compound-engineering"
