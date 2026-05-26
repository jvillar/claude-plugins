---
description: Force a fresh check for upstream updates to all tracked plugins (bypasses 24h cache).
---

Ejecuta el script de chequeo de updates **ignorando la caché de 24h**, para ver el estado actual de upstream en este momento.

Pasos:

1. Borra la caché: `rm -f /tmp/claude-update-watcher-cache.json`
2. Ejecuta el chequeo y muestra el resultado al usuario:
   ```bash
   echo '{}' | python3 "$CLAUDE_PLUGIN_ROOT/scripts/check-updates.py"
   ```
3. Si la salida es `{}`, informa al usuario que todos los plugins trackeados están al día.
4. Si hay updates, muéstrale el `additionalContext` formateado (parsea el JSON y extrae `.hookSpecificOutput.additionalContext`).
5. Recuerda al usuario que para aplicar un update concreto debe usar `/forge-update-watcher:update-apply <plugin-name>`.
