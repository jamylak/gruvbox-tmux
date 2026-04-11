#!/usr/bin/env bash

SHOW_NETSPEED=$(tmux show-option -gv @gruvbox-tmux_show_git 2>/dev/null)
if [ "$SHOW_NETSPEED" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh" || {
  echo "Error: Failed to source themes.sh" >&2
  exit 1
}

TARGET_PATH=${1:-}
if [[ -z $TARGET_PATH ]]; then
  exit 0
fi

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

  if ((interval < 20)); then
    interval=20
  fi

  printf '%s\n' "$interval"
}

build_status() {
  local repo_path=$1
  local branch status sync_mode need_push changed_count insertions_count deletions_count
  local untracked_count last_fetch now remote_diff
  local status_changed="" status_insertions="" status_deletions="" status_untracked=""
  local diff_counts remote_status

  cd "$repo_path" || return 0
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  status=$(git status --porcelain 2>/dev/null | grep -cE "^(M| M)" || true)

  sync_mode=0
  need_push=0
  changed_count=0
  insertions_count=0
  deletions_count=0

  if [[ -z $branch ]]; then
    return 0
  fi

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

      # Keep slow remote refreshes off the tmux foreground render path.
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

acquire_lock() {
  mkdir "$lock_dir" 2>/dev/null
}

release_lock() {
  rmdir "$lock_dir" 2>/dev/null
}

refresh_cache_async() {
  (
    trap release_lock EXIT

    tmp_file=$(mktemp "${CACHE_ROOT}/${CACHE_KEY}.XXXXXX") || exit 0
    status_output=$(build_status "$TARGET_PATH")

    if ! printf '%s' "$status_output" > "$tmp_file"; then
      rm -f "$tmp_file"
      exit 0
    fi

    mv "$tmp_file" "$CACHE_FILE"
  ) >/dev/null 2>&1 </dev/null &
}

CACHE_ROOT="${TMPDIR:-/tmp}/gruvbox-tmux-git-status"
mkdir -p "$CACHE_ROOT" 2>/dev/null || exit 0

CACHE_KEY=$(printf '%s\n' "$TARGET_PATH" | cksum | awk '{print $1}')
CACHE_FILE="${CACHE_ROOT}/${CACHE_KEY}.cache"
lock_dir="${CACHE_ROOT}/${CACHE_KEY}.lock"
TTL=$(cache_ttl)
NOW=$(date +%s)

if [[ -f $CACHE_FILE ]]; then
  printf '%s\n' "$(cat "$CACHE_FILE")"

  CACHE_AGE=$((NOW - $(cache_mtime "$CACHE_FILE")))
  if ((CACHE_AGE < TTL)); then
    exit 0
  fi
else
  printf '\n'
fi

if acquire_lock; then
  refresh_cache_async
fi
