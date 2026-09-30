#!/usr/bin/env bash
# Bootstrap a fresh Mac. Idempotent: safe to re-run.
# Usage:  ./scripts/install-mac.sh
#
# Optional: set POSTMARK_SERVER_TOKEN and DEFAULT_SENDER_EMAIL (e.g. from
# `op read`) to also add the Postmark MCP server to Claude Code.

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
# Upstream installers put br, am, and basecamp here; expose them before shell setup is applied.
export PATH="$HOME/.local/bin:$PATH"

echo
echo "Installing Node.js and npm via mise..."
mise use -g node@latest
# Expose npm global binaries (claude and the tools below) to the rest of this script.
NODE_BIN="$(mise where node@latest)/bin"
export PATH="$NODE_BIN:$PATH"

echo
echo "Installing Claude Code via npm..."
# Run through mise so Node and npm are available before shell setup is applied.
mise exec node@latest -- npm install -g @anthropic-ai/claude-code

echo
echo "Installing global npm tools..."
mise exec node@latest -- npm install -g \
  @shopify/cli \
  agent-browser \
  typescript \
  ts-node \
  typescript-language-server \
  pyright \
  yarn

echo
echo "Installing Beads (br) and Agent Mail (am); bv, ntm, and ubs come from Brewfile..."
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh?$(date +%s)" | bash
# agent mail's installer dumps project-local MCP configs (codex.mcp.json,
# cursor.mcp.json, .vscode/, etc.) into $PWD. Run from a tempdir so that
# noise lands somewhere disposable; the home-level configs it also writes
# (~/.codex, ~/.cursor, etc.) are what actually register the MCP server.
( cd "$(mktemp -d)" && curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail_rust/main/install.sh?$(date +%s)" | bash )

echo
echo "Installing the Basecamp CLI..."
if ! command -v basecamp &>/dev/null; then
  curl -fsSL https://basecamp.com/install-cli | bash
fi

echo
echo "Checking installed tools (br, bv, ntm, am, ubs, claude, basecamp)..."
for tool in br bv ntm am ubs claude basecamp; do
  if ! command -v "$tool"; then
    echo "ERROR: $tool is not on PATH after installation." >&2
    exit 1
  fi
done

echo
echo "Adding user-scope MCP servers to Claude Code..."
# Skip servers that are already configured so re-runs don't fail.
has_mcp() { jq -e --arg name "$1" '.mcpServers[$name]' "$HOME/.claude.json" &>/dev/null; }
for server in \
  "posthog https://mcp.posthog.com/mcp" \
  "granola https://mcp.granola.ai/mcp" \
  "betterstack https://mcp.betterstack.com"; do
  read -r name url <<<"$server"
  has_mcp "$name" || claude mcp add --scope user --transport http "$name" "$url"
done
if has_mcp postmark; then
  :
elif [[ -n "${POSTMARK_SERVER_TOKEN:-}" && -n "${DEFAULT_SENDER_EMAIL:-}" ]]; then
  claude mcp add --scope user postmark \
    -e POSTMARK_SERVER_TOKEN="$POSTMARK_SERVER_TOKEN" \
    -e DEFAULT_SENDER_EMAIL="$DEFAULT_SENDER_EMAIL" \
    -e DEFAULT_MESSAGE_STREAM="${DEFAULT_MESSAGE_STREAM:-outbound}" \
    -- npx -y @activecampaign/postmark-mcp
else
  echo "Skipped the postmark MCP server: set POSTMARK_SERVER_TOKEN and DEFAULT_SENDER_EMAIL, then re-run."
fi

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo
echo "Done. Next steps:"
echo "  1. Initialize chezmoi against this repo (replace the path if you cloned"
echo "     somewhere other than $DOTFILES_DIR):"
echo "       chezmoi init --apply -S \"$DOTFILES_DIR\" \\"
echo "         https://github.com/Scarletbobcat/dotfiles.git"
echo "     Keep the default ~/code/personal/ and ~/code/work/ layout. If your work"
echo "     repos live in ~/code/work/, set projects_dir to that path in"
echo "     ~/.config/chezmoi/chezmoi.toml so NTM finds them."
echo "     On subsequent re-runs you can just use: chezmoi apply"
echo "  2. Restart your terminal (or run 'exec zsh') to pick up the new shell setup"
echo "  3. Log in: 'gh auth login' (once per GitHub account), claude, codex,"
echo "     'stripe login', 'render login', 'terraform login', and docker registries."
echo "     Then run /mcp in Claude Code to authorize posthog, granola, and betterstack."
echo "  4. Put per-machine secrets in ~/.localrc, e.g. GITHUB_PERSONAL_ACCESS_TOKEN"
echo "     (GitHub MCP server) and AGENT_MAIL_TOKEN (NTM)."
echo "  5. Run 'mkcert -install' once before creating local HTTPS certs."
echo "  6. (Optional) Make this machine reachable over your tailnet via Tailscale SSH:"
echo "       ./scripts/setup-tailscale.sh"
echo "  7. (Optional) Install Compound Engineering plugin from inside Claude Code:"
echo "     /plugin marketplace add EveryInc/compound-engineering-plugin"
echo "     /plugin install compound-engineering"
