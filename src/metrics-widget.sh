#!/usr/bin/env bash

show_metrics=$(tmux show-option -gv @gruvbox-tmux_show_metrics 2>/dev/null || echo 1)
if [[ "${show_metrics}" == "0" ]]; then
    exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

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

cache_ttl() {
    local interval
    interval=$(tmux display -p '#{status-interval}' 2>/dev/null || echo 10)

    if ! [[ $interval =~ ^[0-9]+$ ]]; then
        interval=10
    fi

    if ((interval < 2)); then
        interval=2
    fi

    printf '%s\n' "$interval"
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

build_status() {
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

acquire_lock() {
    mkdir "$lock_dir" 2>/dev/null
}

release_lock() {
    rmdir "$lock_dir" 2>/dev/null
}

CACHE_ROOT="${TMPDIR:-/tmp}/gruvbox-tmux-metrics-widget"
mkdir -p "$CACHE_ROOT" 2>/dev/null || exit 0

CACHE_FILE="${CACHE_ROOT}/metrics.cache"
lock_dir="${CACHE_ROOT}/metrics.lock"
TTL=$(cache_ttl)
NOW=$(date +%s)

if [[ -f $CACHE_FILE ]]; then
    CACHE_AGE=$((NOW - $(cache_mtime "$CACHE_FILE")))
    if ((CACHE_AGE < TTL)); then
        printf '%s\n' "$(cat "$CACHE_FILE")"
        exit 0
    fi
fi

if acquire_lock; then
    trap release_lock EXIT

    tmp_file=$(mktemp "${CACHE_ROOT}/metrics.XXXXXX") || exit 0
    status_output=$(build_status)

    if ! printf '%s' "$status_output" > "$tmp_file"; then
        rm -f "$tmp_file"
        exit 0
    fi

    mv "$tmp_file" "$CACHE_FILE"
    printf '%s\n' "$status_output"
    exit 0
fi

if [[ -f $CACHE_FILE ]]; then
    printf '%s\n' "$(cat "$CACHE_FILE")"
else
    printf '%s\n' "$(build_status)"
fi
