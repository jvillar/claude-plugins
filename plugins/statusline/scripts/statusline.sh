#!/bin/sh
input=$(cat)

# ── helpers ──────────────────────────────────────────────────────────────────

make_bar() {
  _pct=${1:-0}; _width=$2
  [ "$_pct" -gt 100 ] 2>/dev/null && _pct=100
  [ "$_pct" -lt 0 ] 2>/dev/null && _pct=0
  _filled=$(( (_pct * _width + 50) / 100 ))
  [ "$_filled" -gt "$_width" ] && _filled=$_width
  [ "$_filled" -lt 0 ] && _filled=0
  _empty=$(( _width - _filled ))
  _bar=""
  _i=0; while [ "$_i" -lt "$_filled" ]; do _bar="${_bar}█"; _i=$((_i+1)); done
  _i=0; while [ "$_i" -lt "$_empty" ];  do _bar="${_bar}░"; _i=$((_i+1)); done
  printf '%s' "$_bar"
}

pick_color_ctx() {
  _p=${1:-0}
  if   [ "$_p" -lt 20 ]; then printf '\033[32m'
  elif [ "$_p" -lt 40 ]; then printf '\033[33m'
  elif [ "$_p" -lt 70 ]; then printf '\033[38;5;208m'
  else printf '\033[31m'; fi
}

pick_color_rate() {
  _p=${1:-0}
  if   [ "$_p" -lt 50 ]; then printf '\033[32m'
  elif [ "$_p" -lt 75 ]; then printf '\033[33m'
  elif [ "$_p" -lt 90 ]; then printf '\033[38;5;208m'
  else printf '\033[31m'; fi
}

fmt_tokens() {
  _t=${1:-0}
  if   [ "$_t" -ge 1000000 ] 2>/dev/null; then echo "$_t" | awk '{printf "%.1fM", $1/1000000}'
  elif [ "$_t" -ge 1000 ] 2>/dev/null;    then echo "$_t" | awk '{printf "%.1fk", $1/1000}'
  else printf '%s' "$_t"; fi
}

reset='\033[0m'
dim='\033[2m'

# ── single jq call — extract everything at once ─────────────────────────────

eval "$(echo "$input" | jq -r '
  "cwd="      + (.cwd // "."),
  "tx_path="  + (.transcript_path // empty),
  "ctx_raw="  + (.context_window.used_percentage // empty | tostring),
  "last_in="  + (.context_window.current_usage.input_tokens // 0 | tostring),
  "last_out=" + (.context_window.current_usage.output_tokens // 0 | tostring),
  "cache_c="  + (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
  "cache_r="  + (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
  "sess_in="  + (.context_window.total_input_tokens // 0 | tostring),
  "sess_out=" + (.context_window.total_output_tokens // 0 | tostring),
  "r5h_raw="  + (.rate_limits.five_hour.used_percentage // empty | tostring),
  "r7d_raw="  + (.rate_limits.seven_day.used_percentage // empty | tostring),
  "r5h_ep="   + (.rate_limits.five_hour.resets_at // empty | tostring),
  "r7d_ep="   + (.rate_limits.seven_day.resets_at // empty | tostring)
' 2>/dev/null)"

folder=$(basename "${cwd:-.}")

# ── git branch — cached 5s ──────────────────────────────────────────────────

GIT_CACHE="/tmp/claude-statusline-git-cache"
GIT_TTL=5

git_refresh=1
if [ -f "$GIT_CACHE" ]; then
  git_age=$(( $(date +%s) - $(stat -f %m "$GIT_CACHE" 2>/dev/null || stat -c %Y "$GIT_CACHE" 2>/dev/null || echo 0) ))
  [ "$git_age" -lt "$GIT_TTL" ] && git_refresh=0
fi
if [ "$git_refresh" -eq 1 ]; then
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no branch")
  printf '%s' "$branch" > "$GIT_CACHE"
else
  branch=$(cat "$GIT_CACHE")
fi

# ── context ──────────────────────────────────────────────────────────────────

ctx_pct=""
[ -n "$ctx_raw" ] && ctx_pct=$(echo "$ctx_raw" | awk '{printf "%d", $1+0.5}')

# ── rate limits — cached 60s ────────────────────────────────────────────────

RATE_CACHE="/tmp/claude-statusline-rate-cache"
RATE_TTL=60

rate_refresh=1
if [ -f "$RATE_CACHE" ]; then
  rate_age=$(( $(date +%s) - $(stat -f %m "$RATE_CACHE" 2>/dev/null || stat -c %Y "$RATE_CACHE" 2>/dev/null || echo 0) ))
  [ "$rate_age" -lt "$RATE_TTL" ] && rate_refresh=0
fi

if [ "$rate_refresh" -eq 1 ]; then
  _r5p=""; _r7p=""; _r5r=""; _r7r=""
  [ -n "$r5h_raw" ] && _r5p=$(echo "$r5h_raw" | awk '{printf "%d", $1+0.5}')
  [ -n "$r7d_raw" ] && _r7p=$(echo "$r7d_raw" | awk '{printf "%d", $1+0.5}')
  [ -n "$r5h_ep" ]  && _r5r=$(date -r "$r5h_ep" '+%H:%M' 2>/dev/null || date -d "@$r5h_ep" '+%H:%M' 2>/dev/null)
  [ -n "$r7d_ep" ]  && _r7r=$(date -r "$r7d_ep" '+%d/%m %H:%M' 2>/dev/null || date -d "@$r7d_ep" '+%d/%m %H:%M' 2>/dev/null)
  printf '%s\n%s\n%s\n%s\n' "$_r5p" "$_r7p" "$_r5r" "$_r7r" > "$RATE_CACHE"
fi

rate5h_pct=$(sed -n '1p' "$RATE_CACHE" 2>/dev/null)
rate7d_pct=$(sed -n '2p' "$RATE_CACHE" 2>/dev/null)
rate5h_reset=$(sed -n '3p' "$RATE_CACHE" 2>/dev/null)
rate7d_reset=$(sed -n '4p' "$RATE_CACHE" 2>/dev/null)

# ── tokens ───────────────────────────────────────────────────────────────────

last_total=$(( ${last_in:-0} + ${last_out:-0} ))
cache_total=$(( ${cache_c:-0} + ${cache_r:-0} ))
session_total=$(( ${sess_in:-0} + ${sess_out:-0} ))

# ── Line 1: folder │ branch ─────────────────────────────────────────────────

printf ' %s │  %s\n' "$folder" "$branch"

# ── Line 2: Context bar │ Rate 5h │ Rate 7d ─────────────────────────────────

if [ -n "$ctx_pct" ]; then
  printf "Ctx $(pick_color_ctx "$ctx_pct")$(make_bar "$ctx_pct" 15)${reset} %s%%" "$ctx_pct"
else
  printf "Ctx ${dim}░░░░░░░░░░░░░░░${reset} n/a"
fi

if [ -n "$rate5h_pct" ]; then
  printf " │ 5h $(pick_color_rate "$rate5h_pct")$(make_bar "$rate5h_pct" 10)${reset} %s%%" "$rate5h_pct"
  [ -n "$rate5h_reset" ] && printf " ${dim}↻%s${reset}" "$rate5h_reset"
else
  printf " │ 5h ${dim}n/a${reset}"
fi

if [ -n "$rate7d_pct" ]; then
  printf " │ 7d $(pick_color_rate "$rate7d_pct")$(make_bar "$rate7d_pct" 10)${reset} %s%%" "$rate7d_pct"
  [ -n "$rate7d_reset" ] && printf " ${dim}↻%s${reset}" "$rate7d_reset"
else
  printf " │ 7d ${dim}n/a${reset}"
fi

printf '\n'

# ── turns count (from transcript JSONL) ─────────────────────────────────────

turns=""
if [ -n "${tx_path:-}" ] && [ -f "$tx_path" ]; then
  turns=$(grep -c '"type":"assistant"' "$tx_path" 2>/dev/null)
fi

pick_color_turns() {
  _t=${1:-0}
  if   [ "$_t" -lt 60 ];  then printf '\033[32m'
  elif [ "$_t" -lt 80 ];  then printf '\033[33m'
  elif [ "$_t" -lt 100 ]; then printf '\033[38;5;208m'
  else printf '\033[31m'; fi
}

# ── Line 3: Token stats │ turns ─────────────────────────────────────────────

printf "${dim}Tokens: msg %s │ cache %s │ session %s${reset}" \
  "$(fmt_tokens $last_total)" "$(fmt_tokens $cache_total)" "$(fmt_tokens $session_total)"

if [ -n "$turns" ]; then
  printf " │ turns $(pick_color_turns "$turns")%s${reset}" "$turns"
fi

printf '\n'
