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
#[fg=${THEME_ghgreen},bg=${THEME_background}]$git_status\
#[fg=${THEME_ghpurple},bg=${THEME_background}]$wb_git_status\
#[fg=${THEME_ghred},bg=${THEME_background}]$battery_status\
$metrics_status\
$date_and_time"

tmux set -g status-right "$right_status"

tmux set -g window-status-separator ""
