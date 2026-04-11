#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/src"

source "$SCRIPTS_PATH/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

build_number_format() {
    local value_format=$1
    local style_name=$2
    local format="$value_format"
    local -a digits
    local index

    case "$style_name" in
        hide)
            printf ''
            return
            ;;
        digital|arabic)
            digits=('0' '1' '2' '3' '4' '5' '6' '7' '8' '9')
            ;;
        fsquare)
            digits=('󰎡' '󰎤' '󰎧' '󰎪' '󰎭' '󰎱' '󰎳' '󰎶' '󰎹' '󰎼')
            ;;
        hsquare)
            digits=('󰎣' '󰎦' '󰎩' '󰎬' '󰎮' '󰎰' '󰎵' '󰎸' '󰎻' '󰎾')
            ;;
        dsquare)
            digits=('󰎢' '󰎥' '󰎨' '󰎫' '󰎲' '󰎯' '󰎴' '󰎷' '󰎺' '󰎽')
            ;;
        super)
            digits=('⁰' '¹' '²' '³' '⁴' '⁵' '⁶' '⁷' '⁸' '⁹')
            ;;
        sub)
            digits=('₀' '₁' '₂' '₃' '₄' '₅' '₆' '₇' '₈' '₉')
            ;;
        earabic)
            digits=('٠' '١' '٢' '٣' '٤' '٥' '٦' '٧' '٨' '٩')
            ;;
        *)
            digits=('0' '1' '2' '3' '4' '5' '6' '7' '8' '9')
            ;;
    esac

    for index in "${!digits[@]}"; do
        format="#{s|$index|${digits[$index]} |:$format}"
    done

    printf '%s' "$format"
}

build_icon_rule() {
    local pattern=$1
    local icon=$2
    local fallback=$3

    printf '#{?#{m/ri:%s,#{pane_current_command}},%s,%s}' \
        "$pattern" "$icon" "$fallback"
}

build_app_icon_format() {
    local default_icon=$1
    local format="${default_icon} "

    format=$(build_icon_rule '^emacs(client)?$' 'λ ' "$format")
    format=$(build_icon_rule '^(nu|nushell)$' '◉ ' "$format")
    format=$(build_icon_rule '^go$' '🐹 ' "$format")
    format=$(build_icon_rule '^psql$' '🐘 ' "$format")
    format=$(build_icon_rule '^uvicorn$' '🦄 ' "$format")
    format=$(build_icon_rule '^(uv|uvx|python.*)$' '🐍 ' "$format")
    format=$(build_icon_rule '^(cargo|rustc|rustup)$' '🦀 ' "$format")
    format=$(build_icon_rule '^deno$' '🦕 ' "$format")
    format=$(build_icon_rule '^bun$' '🥟 ' "$format")
    format=$(build_icon_rule '^yarn$' '🧶 ' "$format")
    format=$(build_icon_rule '^pnpm$' '📫 ' "$format")
    format=$(build_icon_rule '^node$' '⬢ ' "$format")
    format=$(build_icon_rule '^(npm|npx)$' '📦 ' "$format")
    format=$(build_icon_rule '^(docker|docker-compose)$' '🐳 ' "$format")
    format=$(build_icon_rule '^(terraform|tofu)$' '💠 ' "$format")
    format=$(build_icon_rule '^gcloud$' '☁️ ' "$format")
    format=$(build_icon_rule '^glab$' ' ' "$format")
    format=$(build_icon_rule '^gh$' ' ' "$format")
    format=$(build_icon_rule '^tmux$' '🧩 ' "$format")
    format=$(build_icon_rule '^fish$' '🐟 ' "$format")
    format=$(build_icon_rule '^btop$' '📈 ' "$format")
    format=$(build_icon_rule '^lazygit$' ' ' "$format")
    format=$(build_icon_rule '^yazi$' '🗂️ ' "$format")
    format=$(build_icon_rule '^(nvim|vim)$' ' ' "$format")
    format=$(build_icon_rule '^(hx|helix)$' '⌘ ' "$format")
    format=$(build_icon_rule '^(codex|codex-.*)$' "${codex_icon} " "$format")
    format=$(build_icon_rule '^(copilot|copilot-.*|github-copilot-cli|github-copilot-cli-.*|copilot-cli|copilot-cli-.*)$' "${copilot_icon} " "$format")
    format=$(build_icon_rule '^(claude|claude-.*|claude-code|claude-code-.*)$' "${claude_icon} " "$format")
    format=$(build_icon_rule '^ssh$' '󰣀 ' "$format")

    printf '%s' "$format"
}

build_datetime_format() {
    local show_datetime
    local time_format
    local time_string

    show_datetime="$(tmux show-option -gv @gruvbox-tmux_show_datetime 2>/dev/null)"
    if [[ -z "$show_datetime" ]]; then
        show_datetime="$(tmux show-option -gv @gruvbox-tmux_show_time 2>/dev/null)"
    fi

    if [[ "$show_datetime" != "1" ]]; then
        printf ''
        return
    fi

    time_format="$(tmux show-option -gv @gruvbox-tmux_time_format 2>/dev/null)"
    case "$time_format" in
        12H)
            time_string="%I:%M %p "
            ;;
        hide)
            time_string=""
            ;;
        *)
            time_string="%H:%M "
            ;;
    esac

    printf '%s#[fg=%s,bg=%s]▒ 󰥔 %s' \
        "$RESET" "${THEME_purple}" "${THEME_background}" "$time_string"
}

status_interval="$(tmux show-option -gv @gruvbox-tmux_status_interval 2>/dev/null || echo "10")"

tmux set -g status-left-length 80
tmux set -g status-right-length 220
tmux set -g status-interval "$status_interval"

tmux set -g mode-style "fg=${THEME_background},bg=${THEME_foreground},reverse"

tmux set -g message-style "bg=${THEME_bblue},fg=${THEME_background},bold"
tmux set -g message-command-style "fg=${THEME_white},bg=${THEME_black},bold"

tmux set -g pane-border-style "fg=${THEME_bblack}"
tmux set -g pane-active-border-style "fg=${THEME_white},bold"
tmux set -g pane-border-status off

tmux set -g status-style "fg=${THEME_foreground},bg=${THEME_background}"

window_id_style="$(tmux show-option -gv @gruvbox-tmux_window_id_style 2>/dev/null || echo "digital")"
pane_id_style="$(tmux show-option -gv @gruvbox-tmux_pane_id_style 2>/dev/null || echo "hsquare")"
zoom_id_style="$(tmux show-option -gv @gruvbox-tmux_zoom_id_style 2>/dev/null || echo "dsquare")"
terminal_icon="$(tmux show-option -gv @gruvbox-tmux_terminal_icon 2>/dev/null || echo '')"
active_terminal_icon="$(tmux show-option -gv @gruvbox-tmux_active_terminal_icon 2>/dev/null || echo '')"
claude_icon="$(tmux show-option -gv @gruvbox-tmux_claude_icon 2>/dev/null || echo '🌼')"
copilot_icon="$(tmux show-option -gv @gruvbox-tmux_copilot_icon 2>/dev/null || echo '🐙')"
codex_icon="$(tmux show-option -gv @gruvbox-tmux_codex_icon 2>/dev/null || echo '🤖')"

window_icon="$(build_app_icon_format "$terminal_icon")"
active_window_icon="$(build_app_icon_format "$active_terminal_icon")"

status_right="#($SCRIPTS_PATH/status-right.sh #{q:pane_current_path})"
window_number="$(build_number_format '#I' "$window_id_style")"
custom_pane="$(build_number_format '#P' "$pane_id_style")"
zoom_number="$(build_number_format '#P' "$zoom_id_style")"
date_and_time="$(build_datetime_format)"

tmux set -g status-left "\
#[fg=${THEME_foreground},bg=${THEME_blue},bold] \
#{?client_prefix,🚀 ,#{?pane_in_mode,👀 ,🔮 }}\
#[bold,nodim]#S "

tmux set -g window-status-current-format "\
$RESET\
#[fg=${THEME_bgreen},bg=${THEME_bblack}] \
$active_window_icon\
#[fg=${THEME_bpurple},bold,nodim]\
$window_number\
#W\
#[nobold]\
#{?window_zoomed_flag, $zoom_number, $custom_pane}\
#{?window_last_flag, ,}"

tmux set -g window-status-format "\
$RESET\
#[fg=${THEME_foreground}] \
$window_icon\
${RESET}\
$window_number\
#W\
#[nobold,dim]\
#{?window_zoomed_flag, $zoom_number, $custom_pane}\
#[fg=${THEME_yellow}]\
#{?window_last_flag, ,}"

right_status="\
$status_right\
$date_and_time"

tmux set -g status-right "$right_status"

tmux set -g window-status-separator ""
