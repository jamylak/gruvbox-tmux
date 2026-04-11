#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

TARGET_PATH=${1:-}

cache_mtime() {
    local path=$1

    case "$(uname -s)" in
        Darwin*)
            stat -f %m "$path" 2>/dev/null
            ;;
        *)
            stat -c %Y "$path" 2>/dev/null
            ;;
    esac
}

read_file() {
    local path=$1

    [[ -f $path ]] || return 1
    cat "$path"
}

write_cache() {
    local cache_file=$1
    local cache_root=$2
    local output=$3
    local tmp_file

    tmp_file=$(mktemp "${cache_root}/cache.XXXXXX") || return 1
    if ! printf '%s' "$output" > "$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$cache_file"
}

acquire_lock() {
    local lock_dir=$1
    mkdir "$lock_dir" 2>/dev/null
}

release_lock() {
    local lock_dir=$1
    rmdir "$lock_dir" 2>/dev/null
}

refresh_cache_async() {
    local cache_file=$1
    local cache_root=$2
    local lock_dir=$3
    local builder=$4
    shift 4

    (
        local output

        trap 'release_lock "$lock_dir"' EXIT

        output=$("$builder" "$@")
        write_cache "$cache_file" "$cache_root" "$output" || true
    ) >/dev/null 2>&1 </dev/null &
}

render_cached() {
    local ttl=$1
    local cache_root=$2
    local cache_key=$3
    local builder=$4
    shift 4

    local cache_file="${cache_root}/${cache_key}.cache"
    local lock_dir="${cache_root}/${cache_key}.lock"
    local now cache_age

    mkdir -p "$cache_root" 2>/dev/null || {
        "$builder" "$@"
        return
    }

    now=$(date +%s)
    if [[ -f $cache_file ]]; then
        cache_age=$((now - $(cache_mtime "$cache_file")))
        if ((cache_age < ttl)); then
            read_file "$cache_file"
            return
        fi
    fi

    if acquire_lock "$lock_dir"; then
        refresh_cache_async "$cache_file" "$cache_root" "$lock_dir" "$builder" "$@"
    fi

    read_file "$cache_file" 2>/dev/null || printf ''
}

status_interval() {
    local interval
    interval=$(tmux display -p '#{status-interval}' 2>/dev/null || echo 10)

    if ! [[ $interval =~ ^[0-9]+$ ]]; then
        interval=10
    fi

    printf '%s\n' "$interval"
}

git_ttl() {
    local interval
    interval=$(status_interval)
    if ((interval < 20)); then
        interval=20
    fi
    printf '%s\n' "$interval"
}

forge_ttl() {
    local interval
    interval=$(status_interval)
    if ((interval < 60)); then
        interval=60
    fi
    printf '%s\n' "$interval"
}

metrics_ttl() {
    local interval
    interval=$(status_interval)
    if ((interval < 5)); then
        interval=5
    fi
    printf '%s\n' "$interval"
}

build_git_status() {
    local repo_path=$1
    local branch status sync_mode need_push changed_count insertions_count deletions_count
    local untracked_count last_fetch now remote_diff
    local status_changed="" status_insertions="" status_deletions="" status_untracked=""
    local diff_counts remote_status

    [[ -n $repo_path ]] || return 0
    cd "$repo_path" 2>/dev/null || return 0

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -n $branch ]] || return 0

    status=$(git status --porcelain 2>/dev/null | grep -cE "^(M| M)" || true)

    sync_mode=0
    need_push=0
    changed_count=0
    insertions_count=0
    deletions_count=0

    if [[ ${#branch} -gt 25 ]]; then
        branch="${branch:0:25}…"
    fi

    if [[ $status -ne 0 ]]; then
        diff_counts=($(git diff --numstat 2>/dev/null | awk 'NF==3 {changed+=1; ins+=$1; del+=$2} END {printf("%d %d %d", changed, ins, del)}'))
        changed_count=${diff_counts[0]}
        insertions_count=${diff_counts[1]}
        deletions_count=${diff_counts[2]}
        sync_mode=1
    fi

    untracked_count="$(git ls-files --other --directory --exclude-standard | wc -l | tr -d ' ')"

    if [[ $changed_count -gt 0 ]]; then
        status_changed=" ${RESET}#[fg=${THEME_yellow},bg=${THEME_background},bold] ${changed_count}"
    fi

    if [[ $insertions_count -gt 0 ]]; then
        status_insertions=" ${RESET}#[fg=${THEME_green},bg=${THEME_background},bold] ${insertions_count}"
    fi

    if [[ $deletions_count -gt 0 ]]; then
        status_deletions=" ${RESET}#[fg=${THEME_red},bg=${THEME_background},bold] ${deletions_count}"
    fi

    if [[ $untracked_count -gt 0 ]]; then
        status_untracked=" ${RESET}#[fg=${THEME_black},bg=${THEME_background},bold] ${untracked_count}"
    fi

    if [[ $sync_mode -eq 0 ]]; then
        if git rev-parse --verify @{push} >/dev/null 2>&1; then
            need_push=$(git log @{push}.. 2>/dev/null | wc -l | tr -d ' ')
        fi

        if [[ $need_push -gt 0 ]]; then
            sync_mode=2
        else
            last_fetch=0
            if [[ -f .git/FETCH_HEAD ]]; then
                last_fetch=$(cache_mtime .git/FETCH_HEAD || echo 0)
            fi

            now=$(date +%s)
            if [[ $last_fetch -eq 0 || $((now - last_fetch)) -gt 300 ]]; then
                git fetch --quiet --atomic origin --negotiation-tip=HEAD 2>/dev/null || true
            fi

            if git rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
                remote_diff="$(git diff --numstat "${branch}" "origin/${branch}" 2>/dev/null)"
                if [[ -n $remote_diff ]]; then
                    sync_mode=3
                fi
            fi
        fi
    fi

    case "$sync_mode" in
        1)
            remote_status="$RESET#[bg=${THEME_background},fg=${THEME_bred},bold]▒ 󱓎"
            ;;
        2)
            remote_status="$RESET#[bg=${THEME_background},fg=${THEME_red},bold]▒ 󰛃"
            ;;
        3)
            remote_status="$RESET#[bg=${THEME_background},fg=${THEME_bpurple},bold]▒ 󰛀"
            ;;
        *)
            remote_status="$RESET#[bg=${THEME_background},fg=${THEME_green},bold]▒ "
            ;;
    esac

    printf '%s' "$remote_status $RESET$branch$status_changed$status_insertions$status_deletions$status_untracked"
}

build_forge_status() {
    local repo_path=$1
    local branch provider provider_icon=""
    local pr_count=0 review_count=0 issue_count=0 bug_count=0
    local pr_status="" review_status="" issue_status="" bug_status=""
    local res wb_status

    [[ -n $repo_path ]] || return 0
    cd "$repo_path" 2>/dev/null || return 0

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -n $branch ]] || return 0

    provider=$(git config remote.origin.url 2>/dev/null | awk -F '@|:' '{print $2}')

    if [[ $provider == "github.com" ]]; then
        command -v gh >/dev/null 2>&1 || return 0
        command -v jq >/dev/null 2>&1 || return 0

        provider_icon="$RESET#[fg=${THEME_foreground}] "
        pr_count=$(gh pr list --json number --jq 'length' 2>/dev/null || echo 0)
        review_count=$(gh pr status --json reviewRequests --jq '.needsReview | length' 2>/dev/null || echo 0)
        res=$(gh issue list --json "assignees,labels" --assignee @me 2>/dev/null)
        if [[ -n $res ]]; then
            issue_count=$(printf '%s' "$res" | jq 'length' 2>/dev/null || echo 0)
            bug_count=$(printf '%s' "$res" | jq 'map(select(any(.labels[]?; .name == "bug"))) | length' 2>/dev/null || echo 0)
            issue_count=$((issue_count - bug_count))
        fi
    elif [[ $provider == "gitlab.com" ]]; then
        command -v glab >/dev/null 2>&1 || return 0

        provider_icon="$RESET#[fg=#fc6d26] "
        pr_count=$(glab mr list 2>/dev/null | grep -cE "^\!" || true)
        review_count=$(glab mr list --reviewer=@me 2>/dev/null | grep -cE "^\!" || true)
        issue_count=$(glab issue list 2>/dev/null | grep -cE "^\#" || true)
    else
        return 0
    fi

    if ((pr_count > 0)); then
        pr_status="#[fg=${THEME_ghgreen},bg=${THEME_background},bold] ${RESET}${pr_count} "
    fi

    if ((review_count > 0)); then
        review_status="#[fg=${THEME_ghyellow},bg=${THEME_background},bold] ${RESET}${review_count} "
    fi

    if ((issue_count > 0)); then
        issue_status="#[fg=${THEME_ghgreen},bg=${THEME_background},bold] ${RESET}${issue_count} "
    fi

    if ((bug_count > 0)); then
        bug_status="#[fg=${THEME_ghred},bg=${THEME_background},bold] ${RESET}${bug_count} "
    fi

    wb_status="#[fg=${THEME_black},bg=${THEME_background},bold] $RESET$provider_icon $RESET$pr_status$review_status$issue_status$bug_status"
    printf '%s' "$wb_status"
}

clamp_percent() {
    local percent=$1

    if ((percent < 0)); then
        printf '0'
    elif ((percent > 100)); then
        printf '100'
    else
        printf '%s' "$percent"
    fi
}

interpolate_channel() {
    local start=$1
    local end=$2
    local progress=$3

    printf '%d' $((start + ((end - start) * progress / 100)))
}

color_for_percent() {
    local percent
    percent=$(clamp_percent "$1")

    local start_r start_g start_b
    local end_r end_g end_b
    local progress

    if ((percent <= 50)); then
        start_r=0xb8
        start_g=0xbb
        start_b=0x26
        end_r=0xfa
        end_g=0xbd
        end_b=0x2f
        progress=$((percent * 2))
    else
        start_r=0xfa
        start_g=0xbd
        start_b=0x2f
        end_r=0xfb
        end_g=0x49
        end_b=0x34
        progress=$(((percent - 50) * 2))
    fi

    printf '#%02x%02x%02x' \
        "$(interpolate_channel "$start_r" "$end_r" "$progress")" \
        "$(interpolate_channel "$start_g" "$end_g" "$progress")" \
        "$(interpolate_channel "$start_b" "$end_b" "$progress")"
}

bar_for_percent() {
    local percent
    percent=$(clamp_percent "$1")
    local filled=$((percent / 25))
    local empty=$((4 - filled))
    local bar=""
    local i

    for ((i = 0; i < filled; i++)); do
        bar+="■"
    done
    for ((i = 0; i < empty; i++)); do
        bar+="□"
    done

    printf '%s' "$bar"
}

cpu_percent() {
    case "$(uname -s)" in
        Darwin)
            top -l 1 -n 0 | awk -F'[:,% ]+' '/CPU usage/ { printf "%.0f\n", $3 + $5 }'
            ;;
        Linux)
            local total_1 idle_1 total_2 idle_2
            local user nice system idle iowait irq softirq steal

            read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
            total_1=$((user + nice + system + idle + iowait + irq + softirq + steal))
            idle_1=$((idle + iowait))

            sleep 0.2

            read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
            total_2=$((user + nice + system + idle + iowait + irq + softirq + steal))
            idle_2=$((idle + iowait))

            local total_delta=$((total_2 - total_1))
            local idle_delta=$((idle_2 - idle_1))

            if ((total_delta <= 0)); then
                printf '0\n'
            else
                printf '%d\n' $(((100 * (total_delta - idle_delta) + (total_delta / 2)) / total_delta))
            fi
            ;;
        *)
            printf '0\n'
            ;;
    esac
}

ram_percent() {
    case "$(uname -s)" in
        Darwin)
            vm_stat | awk '
                /page size of/ { gsub("\\.", "", $8); page_size=$8 }
                /Pages active/ { gsub("\\.", "", $3); active=$3 }
                /Pages wired down/ { gsub("\\.", "", $4); wired=$4 }
                /Pages occupied by compressor/ { gsub("\\.", "", $5); compressed=$5 }
                /Pages inactive/ { gsub("\\.", "", $3); inactive=$3 }
                /Pages speculative/ { gsub("\\.", "", $3); speculative=$3 }
                /Pages free/ { gsub("\\.", "", $3); free=$3 }
                END {
                    used = active + wired + compressed
                    total = active + wired + compressed + inactive + speculative + free
                    if (total <= 0) {
                        print 0
                    } else {
                        printf "%.0f\n", (used / total) * 100
                    }
                }
            '
            ;;
        Linux)
            free | awk '/^Mem:/ { if ($2 <= 0) { print 0 } else { printf "%.0f\n", ($3 / $2) * 100 } }'
            ;;
        *)
            printf '0\n'
            ;;
    esac
}

build_metrics_status() {
    local cpu ram cpu_bar ram_bar cpu_color ram_color

    cpu=$(clamp_percent "$(cpu_percent)")
    ram=$(clamp_percent "$(ram_percent)")
    cpu_bar=$(bar_for_percent "$cpu")
    ram_bar=$(bar_for_percent "$ram")
    cpu_color=$(color_for_percent "$cpu")
    ram_color=$(color_for_percent "$ram")

    printf '%s#[fg=%s,bg=%s,bold]▒ #[fg=%s,bg=%s,bold]🧠 #[fg=%s,bg=%s,bold]%s %s%% #[fg=%s,bg=%s,bold]💾 #[fg=%s,bg=%s,bold]%s %s%% ' \
        "$RESET" \
        "${THEME_ghyellow}" "${THEME_background}" \
        "${THEME_foreground}" "${THEME_background}" \
        "$cpu_color" "${THEME_background}" \
        "$cpu_bar" "$cpu" \
        "${THEME_foreground}" "${THEME_background}" \
        "$ram_color" "${THEME_background}" \
        "$ram_bar" "$ram"
}

battery_exists() {
    local battery_name=$1

    case "$(uname -s)" in
        Darwin*)
            pmset -g batt | grep -q "$battery_name"
            ;;
        Linux*)
            [[ -d "/sys/class/power_supply/$battery_name" ]]
            ;;
        CYGWIN*|MINGW*|MSYS*|Windows_NT*)
            WMIC PATH Win32_Battery Get EstimatedChargeRemaining 2>/dev/null | grep -q "EstimatedChargeRemaining"
            ;;
        *)
            return 1
            ;;
    esac
}

get_battery_stats() {
    local battery_name=$1
    local battery_status=""
    local battery_percentage=""
    local pmstat

    case "$(uname -s)" in
        Darwin)
            pmstat=$(pmset -g batt | grep "$battery_name")
            battery_status=$(printf '%s' "$pmstat" | awk '{print $4}' | sed 's/[^a-zA-Z]*//g')
            battery_percentage=$(printf '%s' "$pmstat" | awk '{print $3}' | sed 's/[^0-9]*//g')
            ;;
        Linux)
            if [[ -f "/sys/class/power_supply/${battery_name}/status" && -f "/sys/class/power_supply/${battery_name}/capacity" ]]; then
                battery_status=$(<"/sys/class/power_supply/${battery_name}/status")
                battery_percentage=$(<"/sys/class/power_supply/${battery_name}/capacity")
            else
                battery_status="Unknown"
                battery_percentage="0"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*|Windows_NT*)
            battery_percentage=$(WMIC PATH Win32_Battery Get EstimatedChargeRemaining | grep -Eo '[0-9]+')
            [[ -n $battery_percentage ]] && battery_status="Discharging" || battery_status="Unknown"
            ;;
        *)
            battery_status="UnsupportedOS"
            battery_percentage=0
            ;;
    esac

    printf '%s %s\n' "$battery_status" "$battery_percentage"
}

build_battery_status() {
    local show_battery_widget
    local battery_name battery_low default_battery_name
    local battery_status battery_percentage color icon
    local -a discharging_icons charging_icons
    local not_charging_icon no_battery_icon

    show_battery_widget=$(tmux show-option -gv @gruvbox-tmux_show_battery_widget 2>/dev/null)
    [[ "$show_battery_widget" == "1" ]] || return 0

    battery_name=$(tmux show-option -gv @gruvbox-tmux_battery_name 2>/dev/null)
    battery_low=$(tmux show-option -gv @gruvbox-tmux_battery_low_threshold 2>/dev/null)
    battery_low="${battery_low:-20}"

    discharging_icons=('󰁺' '󰁻' '󰁼' '󰁽' '󰁾' '󰁿' '󰂀' '󰂁' '󰂂' '󰁹')
    charging_icons=('󰢜' '󰂆' '󰂇' '󰂈' '󰢝' '󰂉' '󰢞' '󰂊' '󰂋' '󰂅')
    not_charging_icon='󰚥'
    no_battery_icon='󱉝'

    case "$(uname -s)" in
        Darwin*)
            default_battery_name="InternalBattery-0"
            ;;
        Linux*)
            default_battery_name="BAT0"
            ;;
        *)
            default_battery_name="BAT0"
            ;;
    esac
    battery_name="${battery_name:-$default_battery_name}"

    battery_exists "$battery_name" || return 0
    read -r battery_status battery_percentage < <(get_battery_stats "$battery_name")

    if ! [[ $battery_percentage =~ ^[0-9]+$ ]]; then
        battery_percentage=0
    fi

    case "$battery_status" in
        Charging|Charged|charging)
            icon="${charging_icons[$((battery_percentage / 10))]}"
            ;;
        Discharging|discharging)
            icon="${discharging_icons[$((battery_percentage / 10))]}"
            ;;
        Full|charged|full|AC)
            icon="$not_charging_icon"
            ;;
        *)
            icon="$no_battery_icon"
            ;;
    esac

    if [[ "$battery_percentage" -lt "$battery_low" ]]; then
        color="#[fg=${THEME_red},bg=${THEME_background},bold]"
    elif [[ "$battery_percentage" -ge 100 ]]; then
        color="#[fg=${THEME_green},bg=${THEME_background}]"
    else
        color="#[fg=${THEME_yellow},bg=${THEME_background}]"
    fi

    printf '%s░ %s#[bg=%s] %s%% ' "$color" "$icon" "${THEME_background}" "$battery_percentage"
}

show_enabled() {
    local option_name=$1
    local default_value=${2:-1}
    local value

    value=$(tmux show-option -gv "$option_name" 2>/dev/null)
    if [[ -z $value ]]; then
        value=$default_value
    fi

    [[ $value == "1" ]]
}

status=""

if show_enabled "@gruvbox-tmux_show_git" 1; then
    status+=$(render_cached "$(git_ttl)" "${TMPDIR:-/tmp}/gruvbox-tmux-status-right/git" "$(printf '%s\n' "$TARGET_PATH" | cksum | awk '{print $1}')" build_git_status "$TARGET_PATH")
fi

if show_enabled "@gruvbox-tmux_show_wbg" 1; then
    status+=$(render_cached "$(forge_ttl)" "${TMPDIR:-/tmp}/gruvbox-tmux-status-right/forge" "$(printf '%s\n' "$TARGET_PATH" | cksum | awk '{print $1}')" build_forge_status "$TARGET_PATH")
fi

status+=$(build_battery_status)

if show_enabled "@gruvbox-tmux_show_metrics" 1; then
    status+=$(render_cached "$(metrics_ttl)" "${TMPDIR:-/tmp}/gruvbox-tmux-status-right/metrics" "shared" build_metrics_status)
fi

printf '%s' "$status"
