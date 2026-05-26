---
description: Apply the upstream update to a plugin tracked via .upstream-source.json
argument-hint: "<plugin-name>"
---

Aplica la versión upstream del plugin indicado en `$ARGUMENTS`.

Pasos:

1. Si `$ARGUMENTS` está vacío, lista los plugins hermanos con `.upstream-source.json` ejecutando:
   ```bash
   find "$(dirname "$CLAUDE_PLUGIN_ROOT")" -name .upstream-source.json -maxdepth 3 -exec dirname {} \; | xargs -n1 basename
   ```
   Pide al usuario que elija uno y vuelve a invocar.

2. Pregunta al usuario confirmación antes de continuar:
   - Recuérdale que `apply-update.sh` **sobrescribe** los ficheros del plugin con los del upstream.
   - Si tiene cambios locales sin commitear en `plugins/$ARGUMENTS/`, debe stashearlos o commitearlos antes.

3. Ejecuta:
   ```bash
   sh "$CLAUDE_PLUGIN_ROOT/scripts/apply-update.sh" "$ARGUMENTS"
   ```

4. Tras la ejecución, muestra al usuario:
   - La nueva versión instalada y el commit del que viene.
   - El diff sugerido: `git diff -- "plugins/$ARGUMENTS"` (relativo a la raíz del repo del marketplace).
   - Recuérdale que conviene revisar y commitear los cambios.
