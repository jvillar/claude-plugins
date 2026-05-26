# statusline

Three-line statusline for Claude Code:

```
 <folder> │  <branch>
Ctx ████░░░░░░░░░░░ 27% │ 5h ████░░░░░░ 38% ↻18:42 │ 7d ██░░░░░░░░ 23% ↻28/05 10:00
Tokens: msg 12.3k │ cache 1.2M │ session 184k │ turns 42
```

Color-codes:
- **Context**: green < 20% < yellow < 40% < orange < 70% < red.
- **Rate limits**: green < 50% < yellow < 75% < orange < 90% < red.
- **Turns**: green < 60 < yellow < 80 < orange < 100 < red.

Caches `git rev-parse` for 5s and rate-limit panel data for 60s, so it stays cheap on every render.

## Requirements

- `jq` available on `$PATH` (statusline parses Claude's input JSON with it).
- POSIX shell (`/bin/sh`). Tested on macOS and Linux — `stat` / `date` flags have fallbacks for both.

## Install

```
/plugin marketplace add jvillar/claude-plugins
/plugin install statusline@jvillar-claude-plugins
```

Plugins **cannot** auto-register a `statusLine` in your Claude Code config — you have to add it yourself.

After installing the plugin, find where Claude Code put the plugin files (usually `~/.claude/plugins/<marketplace>/plugins/statusline`) and add to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "sh ~/.claude/plugins/jvillar-claude-plugins/plugins/statusline/scripts/statusline.sh"
}
```

Adjust the path to match your actual plugin install location if different.

## Tweaks

Edit `scripts/statusline.sh`:

- **Bar widths**: in the `make_bar` calls (currently `15` for context, `10` for rate bars).
- **Cache TTLs**: `GIT_TTL=5`, `RATE_TTL=60` near the top of their respective sections.
- **Color thresholds**: `pick_color_ctx`, `pick_color_rate`, `pick_color_turns` functions.

## Caveats

- Reads `transcript_path` to count assistant turns. If you delete or move that file mid-session, the turn count silently disappears.
- Rate-limit data comes from the JSON Claude Code passes to the statusline command. If the field shape changes upstream, the bars degrade to `n/a` rather than breaking.
