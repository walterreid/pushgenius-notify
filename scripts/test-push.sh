#!/usr/bin/env bash
# Manual smoke test, no Claude Code needed:
#   PUSHGENIUS_APP_ID=... PUSHGENIUS_API_KEY=... PUSHGENIUS_USER_ID=... ./scripts/test-push.sh
# Add PUSHGENIUS_DRY_RUN=1 to only log the payload.
cd "$(dirname "$0")/.."
printf '%s' '{"hook_event_name":"Stop","cwd":"'"$PWD"'","last_assistant_message":"Test push from pushgenius-notify. If you see this, the hook path works."}' \
  | ./scripts/push.sh
echo "Sent (or dry-ran). Log:"
tail -n 3 "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/pushgenius-notify}/push.log"
