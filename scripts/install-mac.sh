#!/usr/bin/env bash
# Bootstrap a fresh Mac. Idempotent: safe to re-run.
# Usage:  ./scripts/install-mac.sh
#
# Optional: set POSTMARK_SERVER_TOKEN and DEFAULT_SENDER_EMAIL (e.g. from
# `op read`) to also add the Postmark MCP server to Claude Code.
#
# Keep this Bash 3.2 compatible: a fresh Mac runs it with /bin/bash.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
# Progress output. Colors and the live bar only when stdout is a terminal.
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  BLUE=$'\033[1;34m' GREEN=$'\033[1;32m' DIM=$'\033[2m' RESET=$'\033[0m'
else
  BLUE='' GREEN='' DIM='' RESET=''
fi
TOTAL_STEPS=$(grep -c '^step ' "$0")
STEP=0
STEP_START=$SECONDS

format_duration() { printf '%dm %02ds' $(($1 / 60)) $(($1 % 60)); }

print_step_time() {
  printf '%s    done in %s%s\n' "$DIM" "$(format_duration $((SECONDS - STEP_START)))" "$RESET"
}

# Print "==> [3/9] <title>" and the time the previous step took.
step() {
  if ((STEP > 0)); then print_step_time; fi
  STEP=$((STEP + 1))
  STEP_START=$SECONDS
  printf '\n%s==> [%d/%d] %s%s\n' "$BLUE" "$STEP" "$TOTAL_STEPS" "$1" "$RESET"
}

# Redraw "[█████░░░░░] 12/82  Installing ghostty" in place on one line.
draw_bar() {
  local current=$1 total=$2 label=$3 cols=$4 width=30 filled bar_on bar_off max_label
  filled=$((current * width / total))
  printf -v bar_on '%*s' "$filled" ''
  printf -v bar_off '%*s' "$((width - filled))" ''
  max_label=$((cols - width - 14))
  if ((max_label < 10)); then max_label=10; fi
  printf '\r\033[K%s[%s%s]%s %d/%d  %s' "$GREEN" "${bar_on// /█}" "${bar_off// /░}" "$RESET" \
    "$current" "$total" "${label:0:max_label}"
}

# Run `brew bundle` with a live progress bar. brew prints one "Using x" or
# "Installing x" line per Brewfile entry, so count those against the total.
brew_bundle_with_progress() {
  local brewfile=$1 total cols count=0 line status=0
  if [[ ! -t 1 ]]; then
    brew bundle --file="$brewfile"
    return
  fi
  total=$(brew bundle list --file="$brewfile" --all 2>/dev/null | wc -l | tr -d ' ') || total=0
  if ((total == 0)); then
    brew bundle --file="$brewfile"
    return
  fi
  cols=$(tput cols 2>/dev/null || echo 80)
  brew bundle --file="$brewfile" 2>&1 | {
    while IFS= read -r line; do
      case "$line" in
        *" has failed!")
          # brew repeats the entry name on failure; print it, don't count it twice.
          printf '\r\033[K%s\n' "$line"
          draw_bar "$count" "$total" "" "$cols"
          ;;
        "Using "* | "Installing "* | "Upgrading "* | "Skipping "*)
          count=$((count + 1))
          draw_bar "$count" "$total" "$line" "$cols"
          ;;
        *)
          # Errors, warnings, and the final summary print above the bar.
          printf '\r\033[K%s\n' "$line"
          if ((count > 0)); then draw_bar "$count" "$total" "" "$cols"; fi
          ;;
      esac
    done
    printf '\n'
  } || status=$?
  if ((status != 0)); then
    echo "The Brewfile step failed. Fix the errors above, then re-run this script." >&2
  fi
  return "$status"
}

# Download an upstream installer to a temp file, then run it with any extra
# arguments. Piping curl straight into bash fails under pipefail when an
# installer exits before curl finishes sending it. Installers get no stdin,
# as when piped, so they take their non-interactive defaults.
run_installer() {
  local url=$1 tmp status=0
  shift
  tmp=$(mktemp)
  if ! curl -fsSL "$url?$(date +%s)" -o "$tmp"; then
    echo "ERROR: couldn't download installer: $url" >&2
    rm -f "$tmp"
    return 1
  fi
  bash "$tmp" "$@" </dev/null || status=$?
  rm -f "$tmp"
  # 141 is SIGPIPE from an installer's own early exit (e.g. already up to date).
  if ((status != 0 && status != 141)); then
    echo "ERROR: installer failed with exit code $status: $url" >&2
    return "$status"
  fi
}

# Several casks run installers that need an admin password. Ask once up front
# and keep the sudo timestamp fresh, so no prompt appears under the progress bar.
ensure_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo "Some apps need your password to install. Enter it once now:"
    sudo -v
  fi
}
ensure_sudo
while true; do
  sudo -n true 2>/dev/null || true
  sleep 50
  kill -0 "$$" 2>/dev/null || exit
done &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

step "Checking Homebrew"
if ! command -v brew &>/dev/null; then
  echo "Homebrew not installed. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  # Homebrew's installer clears the sudo timestamp when it exits.
  ensure_sudo
else
  echo "Homebrew is already installed."
fi

step "Installing packages from Brewfile (the long one)"
brew_bundle_with_progress "$SCRIPT_DIR/Brewfile"

# Make brew binaries available in this script (Brewfile-installed mise needs to be on PATH)
eval "$(/opt/homebrew/bin/brew shellenv)"
# Upstream installers put br, bv, ntm, am, ubs, and basecamp here; expose them
# before shell setup is applied.
export PATH="$HOME/.local/bin:$PATH"

step "Installing Node.js and npm via mise"
mise use -g node@latest
# Expose npm global binaries (claude and the tools below) to the rest of this script.
NODE_BIN="$(mise where node@latest)/bin"
export PATH="$NODE_BIN:$PATH"

step "Installing Claude Code via npm"
# Run through mise so Node and npm are available before shell setup is applied.
mise exec node@latest -- npm install -g @anthropic-ai/claude-code

step "Installing global npm tools"
mise exec node@latest -- npm install -g \
  @shopify/cli \
  agent-browser \
  typescript \
  ts-node \
  typescript-language-server \
  pyright \
  yarn

step "Installing br, bv, ntm, ubs, and am from their official installers"
# Every tool lands in ~/.local/bin, so each has exactly one copy on PATH.
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
# Earlier versions of this Brewfile installed ntm, bv, and ubs with Homebrew.
# Remove those copies; otherwise they shadow the ones in ~/.local/bin.
for formula in ntm bv ubs; do
  if brew list --formula "dicklesworthstone/tap/$formula" &>/dev/null; then
    echo "Removing the Homebrew copy of $formula..."
    brew uninstall --formula "dicklesworthstone/tap/$formula"
  fi
done
# Installer URLs are the ones each project's README documents. bv's README
# pins its installer to a reviewed commit instead of main.
run_installer "https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh"
INSTALL_DIR="$LOCAL_BIN" run_installer \
  "https://raw.githubusercontent.com/Dicklesworthstone/beads_viewer/a43b8e85a39664381566abdfd85dc8fcbfdcb773/install.sh"
# The managed .zshrc already sets up NTM's shell integration.
run_installer "https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh" \
  --dir="$LOCAL_BIN" --no-shell
# The managed .zshrc already puts ~/.local/bin on PATH.
run_installer "https://raw.githubusercontent.com/Dicklesworthstone/ultimate_bug_scanner/main/install.sh" \
  --install-dir "$LOCAL_BIN" --non-interactive --no-path-modify --skip-hooks
# agent mail's installer dumps project-local MCP configs (codex.mcp.json,
# cursor.mcp.json, .vscode/, etc.) into $PWD. Run from a tempdir so that
# noise lands somewhere disposable; the home-level configs it also writes
# (~/.codex, ~/.cursor, etc.) are what actually register the MCP server.
( cd "$(mktemp -d)" && run_installer "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail_rust/main/install.sh" )

step "Installing the Basecamp CLI"
if ! command -v basecamp &>/dev/null; then
  run_installer "https://raw.githubusercontent.com/basecamp/basecamp-cli/main/scripts/install.sh"
else
  echo "Basecamp CLI is already installed."
fi

step "Checking installed tools"
for tool in br bv ntm am ubs claude basecamp; do
  if tool_path=$(command -v "$tool"); then
    printf '  %s✓%s %-9s %s\n' "$GREEN" "$RESET" "$tool" "$tool_path"
  else
    echo "ERROR: $tool is not on PATH after installation." >&2
    exit 1
  fi
done
# The installer-managed tools should each have exactly one copy, in ~/.local/bin.
for tool in br bv ntm am ubs; do
  copies=$(type -a -p "$tool" | sort -u)
  if (($(echo "$copies" | wc -l) > 1)); then
    echo "  WARNING: $tool is installed in more than one place. Keep $LOCAL_BIN/$tool and remove the others:"
    while IFS= read -r copy; do printf '    %s\n' "$copy"; done <<<"$copies"
  fi
done

step "Adding user-scope MCP servers to Claude Code"
# Skip servers that are already configured so re-runs don't fail.
has_mcp() { jq -e --arg name "$1" '.mcpServers[$name]' "$HOME/.claude.json" &>/dev/null; }
for server in \
  "posthog https://mcp.posthog.com/mcp" \
  "granola https://mcp.granola.ai/mcp" \
  "betterstack https://mcp.betterstack.com"; do
  read -r name url <<<"$server"
  if has_mcp "$name"; then
    echo "  $name: already configured"
  else
    claude mcp add --scope user --transport http "$name" "$url"
  fi
done
if has_mcp postmark; then
  echo "  postmark: already configured"
elif [[ -n "${POSTMARK_SERVER_TOKEN:-}" && -n "${DEFAULT_SENDER_EMAIL:-}" ]]; then
  claude mcp add --scope user postmark \
    -e POSTMARK_SERVER_TOKEN="$POSTMARK_SERVER_TOKEN" \
    -e DEFAULT_SENDER_EMAIL="$DEFAULT_SENDER_EMAIL" \
    -e DEFAULT_MESSAGE_STREAM="${DEFAULT_MESSAGE_STREAM:-outbound}" \
    -- npx -y @activecampaign/postmark-mcp
else
  echo "  postmark: skipped. Set POSTMARK_SERVER_TOKEN and DEFAULT_SENDER_EMAIL, then re-run."
fi

print_step_time
printf '\n%sAll %d steps finished in %s.%s\n' "$GREEN" "$TOTAL_STEPS" "$(format_duration "$SECONDS")" "$RESET"

DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
echo
echo "Next steps:"
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
