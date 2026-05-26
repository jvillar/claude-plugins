#!/bin/sh
# Injects a session-wide style override: rename "haiku" → "haku 🧁".
# Output is parsed by Claude Code as the SessionStart hook contract.

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "[haku-mode] STYLE OVERRIDE ACTIVE FOR THIS SESSION: whenever you refer to the Anthropic model Claude Haiku — in any form (Haiku, haiku, Claude Haiku, claude-haiku, claude-haiku-4-5, haiku-4-5, etc.) — you MUST write it as 'haku 🧁' instead. This applies to: prose answers, code comments, model identifiers in examples, and any user-facing text. Do NOT modify actual API model strings if the user is writing code that calls the API — those must remain literal. The rename is purely a stylistic / conversational rebrand for readability."
  }
}
JSON
