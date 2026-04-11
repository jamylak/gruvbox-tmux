#!/usr/bin/env bash
SHOW_WIDGET=$(tmux show-option -gv @gruvbox-tmux_show_wbg 2>/dev/null || echo 1)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/themes.sh" || {
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
  local branch provider provider_icon=""
  local pr_count=0 review_count=0 issue_count=0 bug_count=0
  local pr_status="" review_status="" issue_status="" bug_status=""
  local res wb_status

  cd "$repo_path" || return 0
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  provider=$(git config remote.origin.url 2>/dev/null | awk -F '@|:' '{print $2}')

  if [[ -z $branch ]]; then
    return 0
  fi

  if [[ $provider == "github.com" ]]; then
    if ! command -v gh &>/dev/null; then
      printf ' '
      return 0
    fi
    provider_icon="$RESET#[fg=${THEME_foreground}] "
    pr_count=$(gh pr list --json number --jq 'length')
    review_count=$(gh pr status --json reviewRequests --jq '.needsReview | length')
    res=$(gh issue list --json "assignees,labels" --assignee @me)
    issue_count=$(echo "$res" | jq 'length')
    bug_count=$(echo "$res" | jq 'map(select(any(.labels[]?; .name == "bug"))) | length')
    issue_count=$((issue_count - bug_count))
  elif [[ $provider == "gitlab.com" ]]; then
    if ! command -v glab &>/dev/null; then
      printf ' '
      return 0
    fi
    provider_icon="$RESET#[fg=#fc6d26] "
    pr_count=$(glab mr list | grep -cE "^\!")
    review_count=$(glab mr list --reviewer=@me | grep -cE "^\!")
    issue_count=$(glab issue list | grep -cE "^\#")
  else
    printf ' '
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

CACHE_ROOT="${TMPDIR:-/tmp}/gruvbox-tmux-wb-git-status"
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
