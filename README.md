# dotfiles

Personal cross-machine config managed by [chezmoi](https://www.chezmoi.io).
Works the same on macOS (Apple Silicon) and Omarchy/Arch Linux.

## Layout

```
.chezmoi.toml.tmpl       Bootstrap config — prompts for identity values on
                         first init, generates ~/.config/chezmoi/chezmoi.toml.
.chezmoiignore           Files in this repo that should NOT be copied to $HOME
                         (per-OS exclusions live here too).

dot_config/              Mirrors ~/.config/. Subdirectories below.
├── ghostty/             Terminal emulator
├── git/                 Templated. Identity from chezmoi.toml + [includeIf]
│                        rules for ~/github/personal/ vs ~/github/work/.
├── ntm/                 Named Tmux Manager config (templated)
├── nvim/                LazyVim setup
├── starship.toml        Prompt config (Omarchy default — Everforest)
├── tmux/                tmux.conf
├── zed/                 Zed editor settings
├── zellij/              Zellij config + layouts (ai-coding.kdl)
└── zsh/aliases.zsh      Cross-platform zsh aliases (sourced from ~/.zshrc)

dot_zshrc.tmpl           Main shell rc, OS-templated for Mac brew paths vs
                         Arch yay paths.

scripts/                 NOT applied to $HOME (.chezmoiignore'd).
├── Brewfile             macOS package list (brew bundle)
├── install-mac.sh       Installs everything in Brewfile + chezmoi + extra CLIs
└── install-omarchy.sh   Same packages via yay (handles official + AUR)
```

Files prefixed `dot_` map to `.` in `$HOME` (chezmoi convention). Files ending
in `.tmpl` are run through Go's text/template at apply time.

## Bootstrap a fresh machine

The repo can live anywhere — `~/github/personal/dotfiles` is just my
convention. Substitute whatever path you cloned to in the commands below;
the install scripts and `chezmoi init` will work from any location.

### macOS

```sh
# Clone the repo wherever you want
git clone https://github.com/Scarletbobcat/dotfiles ~/github/personal/dotfiles
cd ~/github/personal/dotfiles

# Install Homebrew (if missing), all packages from Brewfile (incl. chezmoi),
# and extra CLIs (Claude Code, Codex, beads, agent mail). Idempotent.
./scripts/install-mac.sh

# Initialize chezmoi against this repo (prompts for name + email, populates
# ~/.config/chezmoi/chezmoi.toml, then applies all dotfiles to $HOME)
chezmoi init --apply -S "$(pwd)" \
    https://github.com/Scarletbobcat/dotfiles.git

# Restart your terminal (or `exec zsh`) to pick up the new shell setup
```

The `-S` flag tells chezmoi to use this clone as its source directory
instead of cloning a fresh copy into `~/.local/share/chezmoi/`. The path
gets persisted into `~/.config/chezmoi/chezmoi.toml` (via
`{{ .chezmoi.sourceDir }}` in the template), so subsequent `chezmoi`
commands don't need `-S`.

### Omarchy / Arch

```sh
git clone https://github.com/Scarletbobcat/dotfiles ~/github/personal/dotfiles
cd ~/github/personal/dotfiles
./scripts/install-omarchy.sh
chezmoi init --apply -S "$(pwd)" \
    https://github.com/Scarletbobcat/dotfiles.git
# Log out and back in (or `exec zsh`) so the shell change takes effect.
```

The install script also runs `chsh -s $(which zsh)` if zsh isn't your
default shell yet, and (on re-runs after chezmoi has applied at least
once) drops you straight into a login zsh.

## Per-machine state

Per-machine values live in `~/.config/chezmoi/chezmoi.toml`, which is **not
in this repo**. The init step generates it from `.chezmoi.toml.tmpl`. Looks
like:

```toml
sourceDir = "/Users/tienhoang/github/personal/dotfiles"  # whatever you passed to -S

[data]
    name             = "tienhoang-k2vp"        # work identity (Mac default)
    email            = "tien@k2vp.com"
    git_dir_personal = "~/github/personal/"    # gitdir prefix for personal identity
    git_dir_work     = "~/github/work/"        # gitdir prefix for work identity
    theme_ghostty    = "Everforest Dark Hard"  # Mac theme (Linux uses omarchy)
    theme_nvim       = "everforest"
    theme_nvim_bg    = "soft"
```

Edit this file and `chezmoi apply` to change identity or theme on Mac.

## Git identity routing

Git identity auto-switches based on what directory you're in:

| Path | Identity |
|------|----------|
| Anywhere not matching below | `chezmoi.toml` defaults (`name` / `email` from prompts) |
| Under `git_dir_personal` (default `~/github/personal/`) | personal (Scarletbobcat / yahoo email) |
| Under `git_dir_work` (default `~/github/work/`) | work (tienhoang-k2vp / k2vp email) |

This is `[includeIf "gitdir:..."]` in `~/.config/git/config`, with the
prefixes templated from the `git_dir_personal` and `git_dir_work` chezmoi
data variables. Override them per machine by editing
`~/.config/chezmoi/chezmoi.toml` and running `chezmoi apply`. The override
files (`config-personal`, `config-work`) live in this repo and apply to
both machines. The `[includeIf]` blocks no-op silently when their target
gitdir doesn't exist on a given machine.

## Themes

### Mac
Theme is set by chezmoi data variables. Switch by editing
`~/.config/chezmoi/chezmoi.toml`:

```toml
theme_ghostty = "Tokyo Night"   # any Ghostty built-in theme name
theme_nvim    = "tokyonight"    # any colorscheme loaded by all-themes.lua
theme_nvim_bg = "moon"          # if applicable
```

Then `chezmoi apply` and restart Ghostty / nvim. Available nvim themes are
declared in `dot_config/nvim/lua/plugins/all-themes.lua`.

### Linux (Omarchy)
Themes are managed dynamically by Omarchy itself. Switching theme via the
omarchy menu updates symlinks at `~/.config/omarchy/current/theme/...` and
all themed apps follow. The Mac-only theme variables are unused here.

## Common operations

```sh
chezmoi apply               # apply pending changes from source to $HOME
chezmoi diff                # show what apply would change
chezmoi cd                  # cd into the source directory
chezmoi edit ~/path/to/file # edit the source file (use this, not direct edits)
chezmoi add ~/path/to/file  # start tracking a new file
chezmoi forget ~/path/...   # stop tracking; leaves $HOME copy in place
chezmoi update              # pull from origin and apply
```

The most common gotcha: don't edit a managed file directly in `$HOME` and
expect it to persist. Either edit the source via `chezmoi edit`, or `chezmoi
re-add` after a direct edit.

## What's intentionally not tracked

- `~/.claude.json`, `~/.claude/projects/`, history files — session state
- SSH private keys, GPG keys, AWS credentials — anything secret
- `~/.zsh_history`, `.viminfo` — per-machine usage history
- Per-project app data (browsers, `.git/` directories, etc.)

For per-machine secrets, source `~/.localrc` from `~/.zshrc` (already wired
up) and put env vars there. That file is untracked.
