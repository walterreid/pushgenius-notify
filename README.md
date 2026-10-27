# pushgenius-notify

A Claude Code plugin that pushes a notification to your phone or browser through
[PushGenius](https://pushgeni.us) when Claude finishes a turn, or stops to ask you something.

```
pushgenius-notify/
├── .claude-plugin/plugin.json   manifest + the 4 values Claude Code prompts you for
├── hooks/hooks.json             Stop + Notification hooks (async, never slow the agent)
├── scripts/push.sh              the whole integration: stdin JSON -> one POST
├── scripts/test-push.sh         smoke test without Claude Code
├── skills/pushgenius/SKILL.md   lets you say "push me a test" in a session
└── test-receiver/               one-page local site that turns a Chrome tab into the "device"
```

## 0. Prerequisites
- Claude Code installed, plus `jq` and `curl` on PATH.
- A PushGenius account with one app (dashboard: https://app.pushgeni.us).
- One receiving device registered to that app and logged in with an `external_id`.
  Fastest path: enable **Web push** in the dashboard (Settings > Web push, any site
  address), then serve `test-receiver/` locally and subscribe from Chrome:
  ```bash
  python3 -m http.server 8791 --directory test-receiver
  # open http://localhost:8791/?app=<APP_ID>&id=<EXTERNAL_ID> in Chrome, click Subscribe
  ```
  Localhost counts as a secure origin, so no https is needed. A phone via the
  iOS/Android SDK works the same way. Safari is the easiest receiver on a Mac:
  its web pushes show as normal macOS banners even when Safari is closed. Chrome
  works too but must be running, and on some Macs its banners never appear even
  though the push was delivered (check System Settings > Notifications > Google
  Chrome and Scheduled Summary).
- The app's **REST API key** (Dashboard > Settings). The key is tied to one app, so
  the app ID is optional.

## 1. Smoke test with no Claude involved
```bash
cp .env.example .env.local           # fill in REST key + external_id (app ID optional)
PUSHGENIUS_DRY_RUN=1 ./scripts/test-push.sh          # logs the payload only
./scripts/test-push.sh                                # real send
```
(Or export `PUSHGENIUS_APP_ID`, `PUSHGENIUS_API_KEY`, `PUSHGENIUS_USER_ID` instead of
using `.env`.) If the second one buzzes, the API side is done. A response of
`{"id":"","errors":["All included players are not subscribed"]}` means auth worked but
no device has called `login("<your external_id>")` on this app yet.

## 2. Install it (every session)
```
/plugin install pushgenius-notify --marketplace walterreid/before-compact
```
Claude Code prompts for the REST key, external ID and (optionally) app ID, and keeps
the key in your OS keychain.

## 2b. Or load it from the folder (one session, no install)
```bash
claude plugin validate . --strict       # expect: Validation passed
claude --plugin-dir . plugin list       # expect: pushgenius-notify@inline
claude --plugin-dir .
```
`--plugin-dir` skips the config dialog, so the hooks read `.env` (or exported
`PUSHGENIUS_*` vars). Installing from a marketplace instead prompts for the three
values and stores the REST key in the OS keychain.

Inside the session, `/hooks` should list two entries from `pushgenius-notify`.
Every hook run is logged with the API response:
```bash
tail -n 5 ~/.claude/plugins/data/pushgenius-notify-inline/push.log   # --plugin-dir loads
tail -n 5 ~/.claude/plugins/data/pushgenius-notify/push.log          # marketplace installs
```

## 3. Test prompt
Paste this into the session:

> Using the pushgenius skill, send me a test push that says "hook path works".
> Then tail the plugin's push.log and tell me what the API returned.
> After that, make any trivial edit to a file so this turn ends normally; I'm
> checking that the Stop hook fires on its own.

You should get two pushes: one from the skill (immediate), one from the Stop hook
when Claude finishes the turn. Then run a command that needs permission and don't
answer it; a third push ("Claude needs you") should arrive from the Notification hook.

## 4. Events covered
- `Stop`: "Claude finished", with the last message as the body.
- `StopFailure`: "Claude hit an error", with the API error and its type.
- `Notification`: "Claude needs you" for permission prompts, idle prompts and
  agents waiting on input; "Claude usage limit" for the quota auto-resume events.
- `UserPromptSubmit`: "Claude got your prompt". **Noisy test hook**, one push per
  prompt you type. Delete its entry from `hooks/hooks.json` once pushes are confirmed.

## 5. Things you'll want to change next
- `quiet_seconds` in plugin config: suppress pushes on rapid back-and-forth turns.
- The hard problem is not this plugin, it's key handling: today every user needs
  their own PushGenius app + REST key. The better product shape is a dedicated
  "Agent Notify" app on the PushGenius side with per-user tokens and a thin
  `POST /agent/notify` endpoint, so this hook needs one secret, not three.
- Cloud sessions don't read `~/.claude/settings.json`; plugins and project
  `.claude/settings.json` are how hooks reach them.
