#!/usr/bin/env bash

show_datetime=$(tmux show-option -gv @gruvbox-tmux_show_datetime 2>/dev/null)
if [[ -z "${show_datetime}" ]]; then
    show_datetime=$(tmux show-option -gv @gruvbox-tmux_show_time 2>/dev/null)
fi

if [[ "${show_datetime}" != "1" ]]; then
    exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

time_format=$(tmux show-option -gv @gruvbox-tmux_time_format 2>/dev/null)
time_string=""

case "$time_format" in
    "12H")
        time_string="%I:%M %p "
        ;;
    "hide")
        time_string=""
        ;;
    *)
        time_string="%H:%M "
        ;;
esac

separator="▒"

echo "$RESET#[fg=${THEME[purple]},bg=${THEME[background]}]$separator 󰥔 $time_string"
