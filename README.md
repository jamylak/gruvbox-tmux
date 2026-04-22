󰑓 This been archived in favour of https://github.com/jamylak/rustbox-tmux

----------------

# Gruvbox Tmux

![Bottom Bar](assets/bottom_bar1.png)

This repo is a fork of [motaz-shokry/gruvbox-tmux](https://gitlab.com/motaz-shokry/gruvbox-tmux), but it has diverged into a more opinionated daily-driver tmux status bar focused on development workflows.

It keeps the gruvbox palette, but the layout and widgets are tuned around:

- pane command icons, including Claude Code, Copilot, and Codex as well as eg. Python, Node, etc
- Git repo status in the right status bar
- GitHub/GitLab workbench status via `gh` or `glab`
- battery and system metrics widgets
- a single bounded status renderer with shared caches for the heavier widgets

## Requirements

- tmux
- a Nerd Font
- Bash 3.2+

Optional tools:

- `gh`, `glab`, `jq` for the forge/workbench widget

## Install

With TPM:

```tmux
set -g @plugin "https://github.com/jamylak/gruvbox-tmux"
run "~/.tmux/plugins/tpm/tpm"
```

## What This Fork Does

The default status line is built around a dense bottom bar:

- left: session state icon plus session name
- windows: per-pane command icons, styled window numbers, pane IDs, zoom badge
- right: git status, forge status, battery, CPU/RAM metrics, optional clock

Compared with the original project, this fork also adds or changes:

- custom icons for AI CLIs and common developer tools
- Bash 3.2-compatible scripts for macOS stock Bash
- a single cached right-side renderer for git, forge, battery, and metrics
- a more development-focused default status layout

## Configuration

Minimal setup:

```tmux
set -g @plugin "https://github.com/jamylak/gruvbox-tmux"

set -g @gruvbox-tmux_theme "medium"
set -g @gruvbox-tmux_transparent 0
set -g @gruvbox-tmux_status_interval 10
```

Theme options:

```tmux
set -g @gruvbox-tmux_theme "medium"   # light | soft | medium | hard
set -g @gruvbox-tmux_transparent 0    # 0 | 1
set -g @gruvbox-tmux_status_interval 10
```

Window, pane, and zoom number styles:

```tmux
set -g @gruvbox-tmux_window_id_style digital
set -g @gruvbox-tmux_pane_id_style hsquare
set -g @gruvbox-tmux_zoom_id_style dsquare
```

Supported styles (untested for now):

- `hide`
- `digital`
- `arabic`
- `fsquare`
- `hsquare`
- `dsquare`
- `super`
- `sub`
- `earabic`

Terminal and AI CLI icons:

```tmux
set -g @gruvbox-tmux_terminal_icon ""
set -g @gruvbox-tmux_active_terminal_icon ""
set -g @gruvbox-tmux_claude_icon "🌼"
set -g @gruvbox-tmux_copilot_icon "🐙"
set -g @gruvbox-tmux_codex_icon "🤖"
```

Built-in command icon coverage includes:

- Claude Code, Copilot, Codex
- Neovim/Vim, Helix, Emacs
- Yazi, Lazygit, btop
- fish, tmux, ssh
- gh, glab, gcloud
- Terraform/OpenTofu, Docker, Node package managers
- Rust, Python, Uvicorn, Postgres, Nushell

Widget toggles:

```tmux
set -g @gruvbox-tmux_show_git 1
set -g @gruvbox-tmux_show_wbg 1
set -g @gruvbox-tmux_show_metrics 1
set -g @gruvbox-tmux_show_battery_widget 1   # battery is opt-in
set -g @gruvbox-tmux_show_datetime 0
```

Battery options:

```tmux
set -g @gruvbox-tmux_battery_name "BAT0"
set -g @gruvbox-tmux_battery_low_threshold 25
```

Clock options:

```tmux
set -g @gruvbox-tmux_show_datetime 1
set -g @gruvbox-tmux_time_format "12H"   # 12H | 24H | hide
```

## Notes

- The right side of the status line is rendered by a single shell command per redraw instead of one command per widget.
- The window list uses tmux-native formats for icons and styled numbers, so it does not fork a shell for each window entry.
- Git, forge, and metrics data still use shared caches, but cache refreshes are bounded by `status-interval` rather than triggering extra redraws.
