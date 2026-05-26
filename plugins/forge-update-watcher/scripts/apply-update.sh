#!/bin/sh
# Apply an upstream update to a sibling plugin.
#
# Usage: apply-update.sh <plugin-name>
#
# Strategy: clone (or fetch) the upstream repo into ~/.cache/claude-update-watcher/<repo>,
# rsync the upstream plugin dir over the local one, preserving `.upstream-source.json`
# (and refreshing `cloned_from_commit` + `cloned_at`).
#
# WARNING: this overwrites local changes inside the plugin dir. Commit/stash
# first if you've customized it. Files outside the plugin dir are not touched.

set -eu

PLUGIN_NAME="${1:-}"
if [ -z "$PLUGIN_NAME" ]; then
  echo "Usage: apply-update.sh <plugin-name>" >&2
  exit 2
fi

# Resolve sibling plugin dir
WATCHER_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PLUGINS_DIR="$(dirname "$WATCHER_ROOT")"
TARGET="$PLUGINS_DIR/$PLUGIN_NAME"

if [ ! -d "$TARGET" ]; then
  echo "error: plugin '$PLUGIN_NAME' not found at $TARGET" >&2
  exit 1
fi

UPSTREAM_FILE="$TARGET/.upstream-source.json"
if [ ! -f "$UPSTREAM_FILE" ]; then
  echo "error: $PLUGIN_NAME has no .upstream-source.json" >&2
  exit 1
fi

REPO=$(jq -r '.repo' "$UPSTREAM_FILE")
PLUGIN_PATH=$(jq -r '.plugin_path' "$UPSTREAM_FILE")
if [ -z "$REPO" ] || [ "$REPO" = "null" ] || [ -z "$PLUGIN_PATH" ] || [ "$PLUGIN_PATH" = "null" ]; then
  echo "error: .upstream-source.json missing repo / plugin_path" >&2
  exit 1
fi

CACHE_ROOT="${HOME}/.cache/claude-update-watcher"
mkdir -p "$CACHE_ROOT"
REPO_SLUG=$(echo "$REPO" | tr '/' '_')
UPSTREAM_DIR="$CACHE_ROOT/$REPO_SLUG"

if [ -d "$UPSTREAM_DIR/.git" ]; then
  echo "→ refreshing $REPO in $UPSTREAM_DIR"
  git -C "$UPSTREAM_DIR" fetch --quiet --depth=1 origin
  DEFAULT_BRANCH=$(git -C "$UPSTREAM_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo "main")
  git -C "$UPSTREAM_DIR" reset --hard --quiet "origin/$DEFAULT_BRANCH"
else
  echo "→ cloning $REPO into $UPSTREAM_DIR"
  git clone --quiet --depth=1 "https://github.com/$REPO.git" "$UPSTREAM_DIR"
fi

SRC="$UPSTREAM_DIR/$PLUGIN_PATH"
if [ ! -d "$SRC" ]; then
  echo "error: upstream plugin path not found: $SRC" >&2
  exit 1
fi

# Snapshot data BEFORE overwriting (we restore .upstream-source.json after).
NEW_COMMIT=$(git -C "$UPSTREAM_DIR" rev-parse HEAD)
NEW_VERSION=$(jq -r '.version' "$SRC/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "→ syncing $SRC → $TARGET (version $NEW_VERSION, commit ${NEW_COMMIT%????????????????????????????????})"
# Use rsync if present (preserves permissions and deletes removed files); fall back to cp.
if command -v rsync >/dev/null 2>&1; then
  # --delete removes files that disappeared upstream, but we restore .upstream-source.json after.
  rsync -a --delete --exclude='.upstream-source.json' "$SRC/" "$TARGET/"
else
  rm -rf "$TARGET"/[!.]* "$TARGET"/.[!u]* 2>/dev/null || true
  cp -R "$SRC/." "$TARGET/"
fi

# Rewrite .upstream-source.json with the refreshed snapshot.
cat > "$UPSTREAM_FILE" <<EOF
{
  "repo": "$REPO",
  "plugin_path": "$PLUGIN_PATH",
  "tracked_version": "$NEW_VERSION",
  "cloned_from_commit": "$NEW_COMMIT",
  "cloned_at": "$NOW"
}
EOF

# Invalidate watcher cache so next session check reads fresh state.
rm -f /tmp/claude-update-watcher-cache.json

echo "✓ $PLUGIN_NAME updated to $NEW_VERSION"
echo "  Commit: $NEW_COMMIT"
echo "  Review the diff with: git -C \"$PLUGINS_DIR/..\" diff -- \"plugins/$PLUGIN_NAME\""
