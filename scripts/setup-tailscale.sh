#!/usr/bin/env bash
# Make this machine reachable over your tailnet via Tailscale SSH, so you can
# SSH in from anywhere — including a phone running the Tailscale app + an SSH
# client like Termius — with NO SSH keys to manage (auth is your tailnet
# identity). Idempotent: safe to re-run.
#
# OS detection uses `case "$(uname -s)"`, the same pattern chezmoi's own docs
# use for standalone install hooks. This script lives in scripts/ (which is
# .chezmoiignore'd and run by hand), not as a chezmoi run_ script, because
# Tailscale login is interactive and a deliberate per-machine action — not
# something to fire on every `chezmoi apply`.
#
# Usage:  ./scripts/setup-tailscale.sh

set -euo pipefail

# --- install + start the daemon, per-OS -------------------------------------

setup_macos() {
  if ! command -v tailscale &>/dev/null; then
    echo "Installing tailscale (headless daemon) via Homebrew..."
    brew install tailscale
  fi

  # The Tailscale menu-bar app (App Store or standalone) can't run an SSH
  # server on macOS — only the open-source tailscaled can — so we register it
  # as a root system daemon that starts at boot. install-system-daemon is
  # idempotent; re-running just reloads the launchd plist.
  echo "Registering tailscaled system daemon (needs sudo)..."
  sudo "$(command -v tailscaled)" install-system-daemon

  # Stay reachable while you're away: never sleep on AC power (lid open). On
  # battery the Mac still sleeps. Revert with:  sudo pmset -c sleep 1
  echo "Keeping this Mac awake on AC power so it stays reachable..."
  sudo pmset -c sleep 0
}

setup_linux() {
  if ! command -v tailscale &>/dev/null; then
    echo "Installing tailscale..."
    if command -v yay &>/dev/null; then
      yay -S --needed --noconfirm tailscale
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --needed --noconfirm tailscale
    else
      echo "No yay/pacman found. Install 'tailscale' with your package" >&2
      echo "manager, then re-run this script." >&2
      exit 1
    fi
  fi

  # On Linux the package ships a systemd unit and runs tailscaled as root.
  echo "Enabling tailscaled service (needs sudo)..."
  sudo systemctl enable --now tailscaled
}

case "$(uname -s)" in
  Darwin) setup_macos ;;
  Linux)  setup_linux ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

# --- bring up the tailnet + enable Tailscale SSH ----------------------------

# Resolve an absolute path: sudo's secure_path doesn't include /opt/homebrew.
TAILSCALE="$(command -v tailscale)"

# Give a freshly-started daemon a moment to come up before we talk to it.
sleep 1

if sudo "$TAILSCALE" status &>/dev/null; then
  echo "Already logged in to your tailnet — ensuring Tailscale SSH is on..."
  sudo "$TAILSCALE" set --ssh
else
  echo
  echo "Bringing Tailscale up with SSH enabled."
  echo "A login URL will print below — open it in a browser and authenticate."
  echo
  sudo "$TAILSCALE" up --ssh
fi

echo
echo "Done. This machine is reachable over your tailnet via Tailscale SSH."
echo "  - See its name / IP:   tailscale status"
echo "  - Connect from any tailnet device (incl. phone), no SSH key needed:"
echo "      ssh $USER@<this-machine-name>"
