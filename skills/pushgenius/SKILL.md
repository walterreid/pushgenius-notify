---
name: pushgenius
description: Send, test, or debug push notifications through PushGenius (pushgeni.us). Use when the user asks to "push me", "notify my phone", test the pushgenius-notify plugin, or when the plugin's hook pushes aren't arriving.
---

# PushGenius push notifications

This plugin fires `${CLAUDE_PLUGIN_ROOT}/scripts/push.sh` on `Stop` and on blocking `Notification` events. The same script works for ad-hoc pushes.

## Send an ad-hoc push
Pipe a minimal hook-shaped JSON into the script:
```bash
printf '%s' '{"hook_event_name":"Stop","cwd":"'"$PWD"'","last_assistant_message":"MESSAGE HERE"}' | "${CLAUDE_PLUGIN_ROOT}/scripts/push.sh"
```
Config is read from `CLAUDE_PLUGIN_OPTION_APP_ID`, `_API_KEY`, `_USER_ID` (plugin config) or `PUSHGENIUS_APP_ID`, `PUSHGENIUS_API_KEY`, `PUSHGENIUS_USER_ID` env vars. Never print the API key.

## Debug
1. `tail -n 20 "${CLAUDE_PLUGIN_DATA}/push.log"` shows every attempt and the API response.
2. `/hooks` lists whether the Stop and Notification hooks are registered.
3. A response with an empty `id` and an `errors` array means auth worked but nobody matched `external_id`; check the device logged in with that ID.
4. `jq` and `curl` must be on PATH.

## API shape (for reference)
`POST https://api.pushgeni.us/notifications` with header `Authorization: Key <REST key>` and body
`{"app_id","headings":{"en"},"contents":{"en"},"include_aliases":{"external_id":["<id>"]}}`.
Docs: https://pushgeni.us/docs/api
