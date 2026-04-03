#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/src"

source "$SCRIPTS_PATH/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

status_interval="$(tmux show-option -gv @gruvbox-tmux_status_interval 2>/dev/null || echo "10")"

tmux set -g status-left-length 80
tmux set -g status-right-length 220
tmux set -g status-interval "$status_interval"

tmux set -g mode-style "fg=${THEME[background]},bg=${THEME[foreground]},reverse"

tmux set -g message-style "bg=${THEME[bblue]},fg=${THEME[background]},bold"
tmux set -g message-command-style "fg=${THEME[white]},bg=${THEME[black]},bold"

tmux set -g pane-border-style "fg=${THEME[bblack]}"
tmux set -g pane-active-border-style "fg=${THEME[white]},bold"
tmux set -g pane-border-status off

tmux set -g status-style "fg=${THEME[foreground]},bg=${THEME[background]}"

window_id_style="$(tmux show-option -gv @gruvbox-tmux_window_id_style 2>/dev/null || echo "digital")"
pane_id_style="$(tmux show-option -gv @gruvbox-tmux_pane_id_style 2>/dev/null || echo "hsquare")"
zoom_id_style="$(tmux show-option -gv @gruvbox-tmux_zoom_id_style 2>/dev/null || echo "dsquare")"
terminal_icon="$(tmux show-option -gv @gruvbox-tmux_terminal_icon 2>/dev/null || echo '')"
active_terminal_icon="$(tmux show-option -gv @gruvbox-tmux_active_terminal_icon 2>/dev/null || echo '')"
window_icon="#($SCRIPTS_PATH/app-icon.sh '#{pane_current_command}' 0)"
active_window_icon="#($SCRIPTS_PATH/app-icon.sh '#{pane_current_command}' 1)"

git_status="#($SCRIPTS_PATH/git-status.sh #{pane_current_path})"
wb_git_status="#($SCRIPTS_PATH/wb-git-status.sh #{pane_current_path})"
window_number="#($SCRIPTS_PATH/custom-number.sh #I $window_id_style)"
custom_pane="#($SCRIPTS_PATH/custom-number.sh #I $pane_id_style)"
zoom_number="#($SCRIPTS_PATH/custom-number.sh #P $zoom_id_style)"
date_and_time="$($SCRIPTS_PATH/datetime-widget.sh)"
battery_status="#($SCRIPTS_PATH/battery-widget.sh)"
metrics_status="#($SCRIPTS_PATH/metrics-widget.sh)"

tmux set -g status-left "\
#[fg=${THEME[foreground]},bg=${THEME[blue]},bold] \
#{?client_prefix,🚀 ,#{?pane_in_mode,👀 ,🔮 }}\
#[bold,nodim]#S "

tmux set -g window-status-current-format "\
$RESET\
#[fg=${THEME[bgreen]},bg=${THEME[bblack]}] \
$active_window_icon\
#[fg=${THEME[bpurple]},bold,nodim]\
$window_number\
#W\
#[nobold]\
#{?window_zoomed_flag, $zoom_number, $custom_pane}\
#{?window_last_flag, ,}"

tmux set -g window-status-format "\
$RESET\
#[fg=${THEME[foreground]}] \
$window_icon\
${RESET}\
$window_number\
#W\
#[nobold,dim]\
#{?window_zoomed_flag, $zoom_number, $custom_pane}\
#[fg=${THEME[yellow]}]\
#{?window_last_flag, ,}"

right_status="\
#[fg=${THEME[ghgreen]},bg=${THEME[background]}]$git_status\
#[fg=${THEME[ghpurple]},bg=${THEME[background]}]$wb_git_status\
#[fg=${THEME[ghred]},bg=${THEME[background]}]$battery_status\
$metrics_status\
$date_and_time"

tmux set -g status-right "$right_status"

tmux set -g window-status-separator ""
