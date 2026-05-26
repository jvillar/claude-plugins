# forge-update-watcher

Detecta automáticamente cuándo un plugin hermano tiene una versión nueva en su repo de origen, y permite aplicarla con un comando.

## Cómo funciona

1. **Cada plugin trackeado** lleva un fichero `.upstream-source.json` en su raíz, que apunta al repo y ruta de origen, junto con la versión local de referencia:
   ```json
   {
     "repo": "dmedina-dev/dev-forge",
     "plugin_path": "plugins/forge-hookify",
     "tracked_version": "1.0.3",
     "cloned_from_commit": "330000f7b6c38297b4604bb13ae475ea7126707a",
     "cloned_at": "2026-05-26T08:54:05Z"
   }
   ```

2. **Hook `SessionStart`** (`scripts/check-updates.py`) escanea los plugins hermanos al iniciar cualquier sesión:
   - Lee el `plugin.json` upstream de cada plugin trackeado (vía `gh api` o `curl` a GitHub).
   - Compara `.version` upstream vs local.
   - Si difieren, emite un `additionalContext` con la lista de updates disponibles. Verás algo como:
     > 📦 **Plugin updates available:**
     > - `forge-hookify`: 1.0.3 → **1.1.0** (source: dmedina-dev/dev-forge/plugins/forge-hookify)
     >
     > Apply with: `/forge-update-watcher:update-apply <plugin>`
   - Cachea resultados en `/tmp/claude-update-watcher-cache.json` con TTL 24h para no martillar GitHub.

3. **Comando `/forge-update-watcher:update-check`** — fuerza un chequeo ignorando la caché.

4. **Comando `/forge-update-watcher:update-apply <plugin>`** — ejecuta `apply-update.sh`, que clona/refresca el repo upstream en `~/.cache/claude-update-watcher/`, sincroniza los ficheros del plugin con `rsync --delete` (preservando `.upstream-source.json` y reescribiéndolo con el nuevo commit + versión), e invalida la caché.

## Cómo trackear un plugin nuevo

Cuando clonas/copias un plugin de otro repo a este marketplace, añade un `.upstream-source.json` en su raíz:

```bash
cat > plugins/<nombre>/.upstream-source.json <<EOF
{
  "repo": "owner/repo",
  "plugin_path": "plugins/<nombre>",
  "tracked_version": "<version local copiada>",
  "cloned_from_commit": "<sha del commit en el momento de clonar>",
  "cloned_at": "<ISO8601 UTC>"
}
EOF
```

A partir de ahí, el hook lo detecta automáticamente en cada SessionStart.

## Requisitos

- `python3` (hook) y `sh` (apply script).
- `jq` para parsear JSON en el apply.
- `git` para clonar upstream.
- `gh` (opcional pero recomendado para evitar rate limit anónimo de la API de GitHub) **o** `curl` con acceso público al repo.
- `rsync` recomendado (fallback a `cp` si no está disponible).

## Caveats

- **Sólo trackea repos públicos en GitHub.** Para privados harían falta credenciales — está fuera de scope por ahora.
- **`apply-update.sh` sobrescribe**. No intenta hacer merge. Si tienes cambios locales en el plugin, commitea o stashea antes.
- La comparación es por `version` literal. Cambia el campo `version` en `plugin.json` ↔ se considera distinto. No hay parsing semver.
- El hook nunca bloquea el inicio de sesión: ante cualquier error (red caída, JSON malformado, rate limit) emite `{}` silenciosamente.
- El nombre del plugin sigue la convención `forge-` solo por inspiración del marketplace original; no requiere nada del ecosistema forge.
