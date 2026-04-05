#!/usr/bin/env bash

command_name="${1:-}"
is_active="${2:-0}"
command_name="$(printf '%s' "$command_name" | tr '[:upper:]' '[:lower:]')"

terminal_icon="$(tmux show-option -gv @gruvbox-tmux_terminal_icon 2>/dev/null || echo '')"
active_terminal_icon="$(tmux show-option -gv @gruvbox-tmux_active_terminal_icon 2>/dev/null || echo '')"
claude_icon="$(tmux show-option -gv @gruvbox-tmux_claude_icon 2>/dev/null || echo '🌼')"
copilot_icon="$(tmux show-option -gv @gruvbox-tmux_copilot_icon 2>/dev/null || echo '🐙')"
codex_icon="$(tmux show-option -gv @gruvbox-tmux_codex_icon 2>/dev/null || echo '🤖')"

if [[ "$is_active" == "1" ]]; then
    default_icon="$active_terminal_icon"
else
    default_icon="$terminal_icon"
fi

case "$command_name" in
    ssh)
        icon='󰣀'
        ;;
    claude|claude-*|claude-code|claude-code-*)
        icon="$claude_icon"
        ;;
    copilot|copilot-*|github-copilot-cli|github-copilot-cli-*|copilot-cli|copilot-cli-*)
        icon="$copilot_icon"
        ;;
    codex|codex-*)
        icon="$codex_icon"
        ;;
    hx|helix)
        icon='⌘'
        ;;
    nvim|vim)
        icon=''
        ;;
    yazi)
        icon='🗂️'
        ;;
    lazygit)
        icon=''
        ;;
    btop)
        icon='📈'
        ;;
    fish)
        icon='🐟'
        ;;
    tmux)
        icon='🧩'
        ;;
    gh)
        icon=''
        ;;
    glab)
        icon=''
        ;;
    gcloud)
        icon='☁️'
        ;;
    terraform|tofu)
        icon='💠'
        ;;
    docker|docker-compose)
        icon='🐳'
        ;;
    npm|npx)
        icon='📦'
        ;;
    node)
        icon='⬢'
        ;;
    pnpm)
        icon='📫'
        ;;
    yarn)
        icon='🧶'
        ;;
    bun)
        icon='🥟'
        ;;
    deno)
        icon='🦕'
        ;;
    cargo|rustc|rustup)
        icon='🦀'
        ;;
    uv|uvx|python*)
        icon='🐍'
        ;;
    uvicorn)
        icon='🦄'
        ;;
    psql)
        icon='🐘'
        ;;
    go)
        icon='🐹'
        ;;
    nu|nushell)
        icon='◉'
        ;;
    emacs|emacsclient)
        icon='λ'
        ;;
    *)
        icon="$default_icon"
        ;;
esac

printf '%s ' "$icon"
