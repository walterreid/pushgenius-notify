---
name: events
description: Turn pushgenius-notify pushes on or off per event (stop, error, needs-you, idle, quota, prompt), or show which are on. Use when the user says "/pushgenius-notify:events", "stop pushing on every prompt", "mute the idle push", "which pushes are on", or wants fewer/more PushGenius notifications.
---

# Switch pushes on or off per event

Arguments given: `$ARGUMENTS`

Forms: `status` (or no arguments), `on <event>...`, `off <event>...`.

| Event word | Option | What it covers |
|---|---|---|
| `stop` | `push_on_stop` | Claude finished a turn |
| `error` | `push_on_error` | Turn ended on an API error (StopFailure) |
| `needs-you` | `push_on_needs_you` | Permission prompt, agent waiting on input |
| `idle` | `push_on_idle` | Idle a minute after a turn with no reply |
| `quota` | `push_on_quota` | Usage-limit pause resumed / stale / gave up |
| `prompt` | `push_on_prompt` | Every prompt the user types (test only) |

## Steps

1. Find the installed plugin id (`pushgenius-notify@<marketplace>`, or `pushgenius-notify@inline` for a `--plugin-dir` load):
   ```bash
   claude plugin list 2>/dev/null | grep -o 'pushgenius-notify@[^ ]*' | head -1
   ```
2. For `status`, show the current values and stop:
   ```bash
   claude plugin configure <plugin-id>
   ```
3. For `on` / `off`, map each event word to its option and save the values. Values are the strings `"true"` / `"false"`. Options left out keep their values.
   ```bash
   printf '%s' '{"push_on_prompt":"false","push_on_idle":"false"}' | claude plugin configure <plugin-id> --values-stdin
   ```
4. Tell the user which options changed, and that hooks pick the change up after `/reload-plugins` (or a restart). Do not print the API key; `configure` never shows it either.

An unknown event word: list the six valid words and change nothing.
The same switches are also plain rows in `/config` under the plugin's options.
