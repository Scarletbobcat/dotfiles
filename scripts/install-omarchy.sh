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
  mise # AUR
  github-cli
  git
  chezmoi # dotfiles manager (this very repo)
  jq # required by jackknife setup.sh
  lazygit
  lazydocker # talks to Docker daemon already provided by Omarchy

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
echo "Installing Node via mise (provides runtime for npm-installed CLIs)..."
mise use -g node@latest

echo
echo "Installing global npm CLIs (Claude Code, Codex)..."
npm install -g @anthropic-ai/claude-code @openai/codex

echo
run_installer() {
  local url="$1"
  local tmp
  tmp=$(mktemp)
  if ! curl -fsSL "$url" -o "$tmp"; then
    echo "ERROR: Failed to download installer from $url" >&2
    rm -f "$tmp"
    return 1
  fi
  bash "$tmp" || {
    local code=$?
    # Exit code 141 = SIGPIPE (broken pipe) — means installer exited early
    # (e.g. already up to date). Not a real failure.
    if [[ $code -ne 141 ]]; then
      echo "ERROR: Installer failed with exit code $code ($url)" >&2
      rm -f "$tmp"
      return 1
    fi
  }
  rm -f "$tmp"
}

echo "Installing jackknife stack (beads CLI + agent mail + ntm)..."
run_installer "https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh?$(date +%s)"
# agent mail's installer dumps project-local MCP configs (codex.mcp.json,
# cursor.mcp.json, .vscode/, etc.) into $PWD. Run from a tempdir so that
# noise lands somewhere disposable; the home-level configs it also writes
# (~/.codex, ~/.cursor, etc.) are what actually register the MCP server.
( cd "$(mktemp -d)" && run_installer "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail_rust/main/install.sh?$(date +%s)" )
run_installer "https://raw.githubusercontent.com/Dicklesworthstone/beads_viewer/main/install.sh?$(date +%s)"

echo
echo "Done. Next steps:"
echo "  1. Run 'chezmoi apply' to lay down configs"
echo "  2. Log out and back in (or run 'exec zsh') to pick up the new shell setup"
echo "  3. (Optional) Install Compound Engineering plugin from inside Claude Code:"
echo "     /plugin marketplace add EveryInc/compound-engineering-plugin"
echo "     /plugin install compound-engineering"
