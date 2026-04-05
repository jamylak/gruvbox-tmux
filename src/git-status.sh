#!/usr/bin/env bash

SHOW_NETSPEED=$(tmux show-option -gv @gruvbox-tmux_show_git)
if [ "$SHOW_NETSPEED" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh" || {
  echo "Error: Failed to source themes.sh" >&2
  exit 1
}

cd "$1" || exit 1
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
STATUS=$(git status --porcelain 2>/dev/null | grep -cE "^(M| M)" || true)

SYNC_MODE=0
NEED_PUSH=0
CHANGED_COUNT=0
INSERTIONS_COUNT=0
DELETIONS_COUNT=0

if [[ ${#BRANCH} -gt 25 ]]; then
  BRANCH="${BRANCH:0:25}…"
fi

STATUS_CHANGED=""
STATUS_INSERTIONS=""
STATUS_DELETIONS=""
STATUS_UNTRACKED=""

if [[ $STATUS -ne 0 ]]; then
  DIFF_COUNTS=($(git diff --numstat 2>/dev/null | awk 'NF==3 {changed+=1; ins+=$1; del+=$2} END {printf("%d %d %d", changed, ins, del)}'))
  CHANGED_COUNT=${DIFF_COUNTS[0]}
  INSERTIONS_COUNT=${DIFF_COUNTS[1]}
  DELETIONS_COUNT=${DIFF_COUNTS[2]}

  SYNC_MODE=1
fi

UNTRACKED_COUNT="$(git ls-files --other --directory --exclude-standard | wc -l | tr -d ' ')"

if [[ $CHANGED_COUNT -gt 0 ]]; then
  STATUS_CHANGED=" ${RESET}#[fg=${THEME_yellow},bg=${THEME_background},bold] ${CHANGED_COUNT}"
fi

if [[ $INSERTIONS_COUNT -gt 0 ]]; then
  STATUS_INSERTIONS=" ${RESET}#[fg=${THEME_green},bg=${THEME_background},bold] ${INSERTIONS_COUNT}"
fi

if [[ $DELETIONS_COUNT -gt 0 ]]; then
  STATUS_DELETIONS=" ${RESET}#[fg=${THEME_red},bg=${THEME_background},bold] ${DELETIONS_COUNT}"
fi

if [[ $UNTRACKED_COUNT -gt 0 ]]; then
  STATUS_UNTRACKED=" ${RESET}#[fg=${THEME_black},bg=${THEME_background},bold] ${UNTRACKED_COUNT}"
fi

# Determine repository sync status
if [[ $SYNC_MODE -eq 0 ]]; then
  if git rev-parse --verify @{push} >/dev/null 2>&1; then
    NEED_PUSH=$(git log @{push}.. 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [[ $NEED_PUSH -gt 0 ]]; then
    SYNC_MODE=2
  else
    LAST_FETCH=0
    if [[ -f .git/FETCH_HEAD ]]; then
      case "$(uname -s)" in
        Darwin*)
          LAST_FETCH=$(stat -f %m .git/FETCH_HEAD 2>/dev/null || echo 0)
          ;;
        *)
          LAST_FETCH=$(stat -c %Y .git/FETCH_HEAD 2>/dev/null || echo 0)
          ;;
      esac
    fi

    NOW=$(date +%s)

    # if 5 minutes have passed since the last fetch
    if [[ $LAST_FETCH -eq 0 || $((NOW - LAST_FETCH)) -gt 300 ]]; then
      git fetch --quiet --atomic origin --negotiation-tip=HEAD 2>/dev/null || true
    fi

    # Check if the remote branch is ahead of the local branch
    if git rev-parse --verify "origin/${BRANCH}" >/dev/null 2>&1; then
      REMOTE_DIFF="$(git diff --numstat "${BRANCH}" "origin/${BRANCH}" 2>/dev/null)"
      if [[ -n $REMOTE_DIFF ]]; then
        SYNC_MODE=3
      fi
    fi
  fi
fi

# Set the status indicator based on the sync mode
case "$SYNC_MODE" in
1)
  REMOTE_STATUS="$RESET#[bg=${THEME_background},fg=${THEME_bred},bold]▒ 󱓎"
  ;;
2)
  REMOTE_STATUS="$RESET#[bg=${THEME_background},fg=${THEME_red},bold]▒ 󰛃"
  ;;
3)
  REMOTE_STATUS="$RESET#[bg=${THEME_background},fg=${THEME_bpurple},bold]▒ 󰛀"
  ;;
*)
  REMOTE_STATUS="$RESET#[bg=${THEME_background},fg=${THEME_green},bold]▒ "
  ;;
esac

if [[ -n $BRANCH ]]; then
  printf '%s' "$REMOTE_STATUS $RESET$BRANCH$STATUS_CHANGED$STATUS_INSERTIONS$STATUS_DELETIONS$STATUS_UNTRACKED"
fi
