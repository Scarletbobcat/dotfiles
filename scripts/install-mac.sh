#!/usr/bin/env bash
# Bootstrap a fresh Mac. Idempotent: safe to re-run.
# Usage:  ./scripts/install-mac.sh

set -euo pipefail

if ! command -v brew &>/dev/null; then
  echo "Homebrew not installed. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "Installing packages from Brewfile..."
brew bundle --file="$(dirname "$0")/Brewfile"

# Make brew binaries available in this script (Brewfile-installed mise needs to be on PATH)
eval "$(/opt/homebrew/bin/brew shellenv)"

echo
echo "Installing Node via mise (provides runtime for npm-installed CLIs)..."
mise use -g node@latest

echo
echo "Installing global npm CLIs (Claude Code, Codex)..."
npm install -g @anthropic-ai/claude-code @openai/codex

echo
echo "Installing beads CLI + agent mail..."
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh?$(date +%s)" | bash
# agent mail's installer dumps project-local MCP configs (codex.mcp.json,
# cursor.mcp.json, .vscode/, etc.) into $PWD. Run from a tempdir so that
# noise lands somewhere disposable; the home-level configs it also writes
# (~/.codex, ~/.cursor, etc.) are what actually register the MCP server.
( cd "$(mktemp -d)" && curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail_rust/main/install.sh?$(date +%s)" | bash )

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo
echo "Done. Next steps:"
echo "  1. Initialize chezmoi against this repo (replace the path if you cloned"
echo "     somewhere other than $DOTFILES_DIR):"
echo "       chezmoi init --apply -S \"$DOTFILES_DIR\" \\"
echo "         https://github.com/Scarletbobcat/dotfiles.git"
echo "     On subsequent re-runs you can just use: chezmoi apply"
echo "  2. Restart your terminal (or run 'exec zsh') to pick up the new shell setup"
echo "  3. (Optional) Install Compound Engineering plugin from inside Claude Code:"
echo "     /plugin marketplace add EveryInc/compound-engineering-plugin"
echo "     /plugin install compound-engineering"
