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

echo
echo "Done. Next steps:"
echo "  1. Run 'chezmoi apply' to lay down configs"
echo "  2. Restart your terminal (or run 'exec zsh') to pick up the new shell setup"
