# haku

Replaces `haiku` with `haku 🧁` in Claude's responses. Stylistic only — does not touch literal API model strings in code.

## Install

```
/plugin marketplace add jvillar/claude-plugins
/plugin install haku@jvillar-claude-plugins
```

Open a new session for the SessionStart hook to fire.

## Caveat

The instruction is injected as session context, not enforced. The model may slip in long sessions. `/clear` to reset.
