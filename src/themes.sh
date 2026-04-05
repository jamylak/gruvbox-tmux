#!/usr/bin/env bash

SELECTED_THEME="$(tmux show-option -gv @gruvbox-tmux_theme 2>/dev/null || echo "medium")"
TRANSPARENT_THEME="$(tmux show-option -gv @gruvbox-tmux_transparent 2>/dev/null || echo 0)"

light_background="#F9F5D7"
light_foreground="#1b1b1b"
light_black="#F9F5D7"
light_blue="#458588"
light_aqua="#689d6a"
light_green="#98971a"
light_purple="#b16286"
light_red="#cc241d"
light_white="#1b1b1b"
light_yellow="#d79921"
light_bblack="#EBDBB2"
light_bblue="#076678"
light_baqua="#427B58"
light_bgreen="#79740E"
light_bpurple="#8F3F71"
light_bred="#9D0006"
light_bwhite="#282828"
light_byellow="#B57614"

soft_background="#32302F"
soft_foreground="#fbf1c7"
soft_black="#32302F"
soft_blue="#458588"
soft_aqua="#689d6a"
soft_green="#98971a"
soft_purple="#b16286"
soft_red="#cc241d"
soft_white="#fbf1c7"
soft_yellow="#d79921"
soft_bblack="#3C3836"
soft_bblue="#83a598"
soft_baqua="#8ec07c"
soft_bgreen="#b8bb26"
soft_bpurple="#d3869b"
soft_bred="#fb4934"
soft_bwhite="#EBDBB2"
soft_byellow="#fabd2f"

medium_background="#282828"
medium_foreground="#fbf1c7"
medium_black="#282828"
medium_blue="#458588"
medium_aqua="#689d6a"
medium_green="#98971a"
medium_purple="#b16286"
medium_red="#cc241d"
medium_white="#fbf1c7"
medium_yellow="#d79921"
medium_bblack="#32302F"
medium_bblue="#83a598"
medium_baqua="#8ec07c"
medium_bgreen="#b8bb26"
medium_bpurple="#d3869b"
medium_bred="#fb4934"
medium_bwhite="#EBDBB2"
medium_byellow="#fabd2f"

hard_background="#1b1b1b"
hard_foreground="#fbf1c7"
hard_black="#1b1b1b"
hard_blue="#458588"
hard_aqua="#689d6a"
hard_green="#98971a"
hard_purple="#b16286"
hard_red="#cc241d"
hard_white="#fbf1c7"
hard_yellow="#d79921"
hard_bblack="#282828"
hard_bblue="#83a598"
hard_baqua="#8ec07c"
hard_bgreen="#b8bb26"
hard_bpurple="#d3869b"
hard_bred="#fb4934"
hard_bwhite="#EBDBB2"
hard_byellow="#fabd2f"

set_theme_color() {
    local key=$1
    local selected_var="${SELECTED_THEME}_${key}"
    local fallback_var="hard_${key}"
    local value=""

    eval "value=\${${selected_var}:-}"
    if [[ -z "$value" ]]; then
        eval "value=\${${fallback_var}}"
    fi

    eval "THEME_${key}=\$value"
}

for key in background foreground black blue aqua green purple red white yellow \
           bblack bblue baqua bgreen bpurple bred bwhite byellow; do
    set_theme_color "$key"
done

if [[ "${TRANSPARENT_THEME}" == "1" ]]; then
    THEME_background="default"
fi

THEME_ghgreen="#b8bb26"
THEME_ghpurple="#d3869b"
THEME_ghred="#fb4934"
THEME_ghyellow="#fabd2f"

RESET="#[fg=${THEME_foreground},bg=${THEME_background},nobold,noitalics,nounderscore,nodim]"
