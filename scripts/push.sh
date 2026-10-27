#!/usr/bin/env bash
# PushGenius hook: reads Claude Code's hook JSON on stdin, sends one push.
# Config comes from plugin userConfig (CLAUDE_PLUGIN_OPTION_*) with env-var fallbacks
# so the same script works when loaded via --plugin-dir without the config dialog.
set -u

# Optional: a .env file in the plugin root (gitignored) for --plugin-dir use and
# for scripts/test-push.sh. Plugin userConfig (CLAUDE_PLUGIN_OPTION_*) still wins.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
for f in "$PLUGIN_ROOT/.env" "$PLUGIN_ROOT/.env.local"; do
  if [ -f "$f" ]; then set -a; . "$f"; set +a; fi
done

APP_ID="${CLAUDE_PLUGIN_OPTION_APP_ID:-${PUSHGENIUS_APP_ID:-}}"
API_KEY="${CLAUDE_PLUGIN_OPTION_API_KEY:-${PUSHGENIUS_API_KEY:-}}"
USER_ID="${CLAUDE_PLUGIN_OPTION_USER_ID:-${PUSHGENIUS_USER_ID:-}}"
QUIET="${CLAUDE_PLUGIN_OPTION_QUIET_SECONDS:-${PUSHGENIUS_QUIET_SECONDS:-0}}"
DRY_RUN="${PUSHGENIUS_DRY_RUN:-0}"

DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/pushgenius-notify}"
mkdir -p "$DATA_DIR"
LOG="$DATA_DIR/push.log"
STAMP="$DATA_DIR/last_push"

log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$LOG"; }

command -v jq >/dev/null 2>&1 || { log "jq not installed; skipping"; exit 0; }

INPUT="$(cat)"
EVENT="$(jq -r '.hook_event_name // "unknown"' <<<"$INPUT")"
CWD="$(jq -r '.cwd // ""' <<<"$INPUT")"
PROJECT="$(basename "${CWD:-project}")"

# Skip Stop pushes that are just the tail of a stop-hook continuation loop.
if [ "$EVENT" = "Stop" ] && [ "$(jq -r '.stop_hook_active // false' <<<"$INPUT")" = "true" ]; then
  log "Stop: stop_hook_active, skipping"; exit 0
fi

case "$EVENT" in
  Stop)
    TITLE="Claude finished: $PROJECT"
    BODY="$(jq -r '.last_assistant_message // "Turn complete."' <<<"$INPUT")"
    if [ "${QUIET%.*}" -gt 0 ] 2>/dev/null && [ -f "$STAMP" ]; then
      LAST="$(cat "$STAMP" 2>/dev/null || echo 0)"; NOW="$(date +%s)"
      if [ $((NOW - LAST)) -lt "${QUIET%.*}" ]; then log "Stop: inside quiet period, skipping"; exit 0; fi
    fi
    ;;
  StopFailure)
    ERR="$(jq -r '.error // "unknown"' <<<"$INPUT")"
    TITLE="Claude hit an error: $PROJECT"
    BODY="$(jq -r '.last_assistant_message // .error_details // "API error"' <<<"$INPUT") [$ERR]"
    ;;
  UserPromptSubmit)
    # Noisy test event: one push per prompt you type. Remove from hooks.json when done testing.
    TITLE="Claude got your prompt: $PROJECT"
    BODY="$(jq -r '.prompt // "(empty prompt)"' <<<"$INPUT")"
    ;;
  Notification)
    KIND="$(jq -r '.notification_type // "attention"' <<<"$INPUT")"
    case "$KIND" in
      quota_auto_resume_*) TITLE="Claude usage limit: $PROJECT" ;;
      *)                   TITLE="Claude needs you: $PROJECT" ;;
    esac
    BODY="$(jq -r '.message // "Claude is waiting on input."' <<<"$INPUT") [$KIND]"
    ;;
  *)
    TITLE="Claude Code: $PROJECT"
    BODY="$(jq -r '.message // .last_assistant_message // "Event: '"$EVENT"'"' <<<"$INPUT")"
    ;;
esac

# Prefix the title with the hook that fired, e.g. [Stop] or [Notification:permission_prompt].
LABEL="$EVENT"; [ "$EVENT" = "Notification" ] && LABEL="Notification:${KIND:-?}"
TITLE="[$LABEL] $TITLE"

# Collapse whitespace, trim to a notification-sized body.
BODY="$(printf '%s' "$BODY" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-180)"

# app_id is optional: the REST key is already scoped to one app.
PAYLOAD="$(jq -nc \
  --arg app "$APP_ID" --arg t "$TITLE" --arg b "$BODY" --arg u "$USER_ID" \
  '{headings:{en:$t}, contents:{en:$b}, include_aliases:{external_id:[$u]}}
   + (if $app != "" then {app_id:$app} else {} end)')"

if [ "$DRY_RUN" = "1" ]; then
  log "DRY RUN $EVENT -> $PAYLOAD"; exit 0
fi

if [ -z "$API_KEY" ] || [ -z "$USER_ID" ]; then
  log "$EVENT: missing API_KEY/USER_ID; not sending"; exit 0
fi

RESP="$(curl -sS -m 15 https://api.pushgeni.us/notifications \
  -H "Authorization: Key $API_KEY" -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>&1)"
log "$EVENT -> $RESP"
[ "$EVENT" = "Stop" ] && date +%s > "$STAMP"
exit 0
