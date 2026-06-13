#!/usr/bin/env bash
# Change Scope Pre-Edit Gate — PreToolUse hook
#
# BLOCKS Edit/Write/MultiEdit on files outside the active scope manifest,
# unless the manifest was edited recently (within the last N seconds — proxy for
# "you just deliberately expanded scope, now editing the file"). Implements the
# scope-before-code accountability layer for change-scope discipline.
#
# Source: docs/change-scope-discipline.md (bundled with this plugin).
#
# Trigger: PreToolUse, matcher Edit|Write|MultiEdit.
#
# Silent allow rules (no block, no message):
#   - Tool isn't Edit/Write/MultiEdit (defensive — matcher should handle)
#   - No file_path in tool_input
#   - Not inside a git work tree (script may be running in a temp dir)
#   - No scope manifest under .planning/ (project hasn't adopted the discipline)
#   - Target IS the scope manifest being edited (you're declaring scope)
#   - Target matches a pattern in the manifest's "Files in scope" bullet list
#   - Target matches a pattern in .scope-ignore
#   - manifest mtime within $SCOPE_RECENT_WINDOW seconds (default 600 = 10 min)
#   - $SCOPE_BYPASS_REASON env var is set (logged to audit trail)
#
# BLOCK:
#   - Everything else, with a clear reason + bypass instructions
#
# Failure mode: silent allow (exit 0, no JSON) on any error — never block a
# legitimate edit because our own logic has a bug.

set -u

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Find the project root (closest .git/ ancestor). If we're not in a git tree,
# silent allow — the discipline only enforces inside tracked projects.
PROJECT_ROOT=""
search_dir=$(dirname "$FILE_PATH")
while [ "$search_dir" != "/" ] && [ "$search_dir" != "." ]; do
  if [ -d "$search_dir/.git" ] || [ -f "$search_dir/.git" ]; then
    PROJECT_ROOT="$search_dir"
    break
  fi
  search_dir=$(dirname "$search_dir")
done
[ -z "$PROJECT_ROOT" ] && exit 0

# ── Locate the active scope manifest ─────────────────────────────────
# Scope manifests live in .planning/ ONLY. Layouts:
#   FLAT      — .planning/<workstream>-scope.md  +  .planning/SCOPE.md
#   SUBFOLDER — .planning/<plan-name>/scope.md
SCOPE_FILE=""
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
shopt -s nullglob
candidates=(.planning/*-scope.md .planning/SCOPE.md .planning/*/scope.md .planning/*/SCOPE.md)
shopt -u nullglob
newest_mtime=0
for c in "${candidates[@]}"; do
  m=$(stat -f %m "$c" 2>/dev/null || stat -c %Y "$c" 2>/dev/null || echo 0)
  if [ "${m:-0}" -gt "$newest_mtime" ]; then
    newest_mtime=$m
    SCOPE_FILE="$PROJECT_ROOT/$c"
  fi
done

# Project hasn't adopted → silent allow
[ -z "$SCOPE_FILE" ] || [ ! -f "$SCOPE_FILE" ] && exit 0

# ── Relative path of target (for glob matching against scope entries) ─
REL_PATH="${FILE_PATH#"$PROJECT_ROOT"/}"

# Editing the manifest itself → allow (you're declaring scope).
case "$REL_PATH" in
  SCOPE.md|.planning/*-scope.md|.planning/SCOPE.md|.planning/*/scope.md|.scope-ignore) exit 0 ;;
esac

# ── Bypass via env var (audit-logged) ────────────────────────────────
BYPASS_REASON="${SCOPE_BYPASS_REASON:-}"
if [ -n "$BYPASS_REASON" ]; then
  audit_dir="$HOME/.claude/log"
  mkdir -p "$audit_dir" 2>/dev/null
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"ts":"%s","project":"%s","file":"%s","reason":%s}\n' \
    "$ts" "$PROJECT_ROOT" "$FILE_PATH" \
    "$(printf '%s' "$BYPASS_REASON" | jq -Rs .)" \
    >> "$audit_dir/scope-bypasses.jsonl" 2>/dev/null
  exit 0
fi

# ── Parse manifest "Files in scope" patterns ─────────────────────────
# The path/glob is the WHOLE bullet (minus a trailing " — rationale"), NOT the
# first whitespace token — so paths CONTAINING SPACES (e.g. "App Dir/...") are
# matched correctly. Negations (!) are handled by .scope-ignore below.
SCOPE_PATTERNS=()
while IFS= read -r raw; do
  line="${raw#"${raw%%[![:space:]]*}"}"           # strip leading whitespace
  case "$line" in "- "*) ;; *) continue ;; esac
  item="${line#- }"
  case "$item" in "!"*) continue ;; esac          # negation → .scope-ignore handles it
  item="${item//\`/}"                             # strip backticks
  case "$item" in *" — "*) item="${item%% — *}" ;; esac   # strip em-dash rationale
  item="${item%"${item##*[![:space:]]}"}"         # trim trailing whitespace
  [ -z "$item" ] && continue
  SCOPE_PATTERNS+=("$item")
done < <(sed 's/[[:space:]]*#.*$//' "$SCOPE_FILE")

match_any_glob() {
  local target="$1"; shift
  local pat
  for pat in "$@"; do
    # shellcheck disable=SC2254  # intentional glob in case pattern
    case "$target" in $pat) return 0 ;; esac
  done
  return 1
}

# Target matches a scope pattern → allow
if [ "${#SCOPE_PATTERNS[@]}" -gt 0 ] && match_any_glob "$REL_PATH" "${SCOPE_PATTERNS[@]}"; then
  exit 0
fi

# ── .scope-ignore allowlist ──────────────────────────────────────────
if [ -f "$PROJECT_ROOT/.scope-ignore" ]; then
  mapfile -t IGNORE_PATTERNS < <(
    grep -vE '^[[:space:]]*(#|$)' "$PROJECT_ROOT/.scope-ignore"
  )
  if [ "${#IGNORE_PATTERNS[@]}" -gt 0 ] && match_any_glob "$REL_PATH" "${IGNORE_PATTERNS[@]}"; then
    exit 0
  fi
fi

# ── Recent manifest edit grace window ────────────────────────────────
SCOPE_RECENT_WINDOW="${SCOPE_RECENT_WINDOW:-600}"
scope_mtime=$(stat -f %m "$SCOPE_FILE" 2>/dev/null || stat -c %Y "$SCOPE_FILE" 2>/dev/null || echo 0)
now=$(date +%s)
elapsed=$((now - scope_mtime))
if [ "$elapsed" -lt "$SCOPE_RECENT_WINDOW" ]; then
  exit 0
fi

# ── BLOCK ─────────────────────────────────────────────────────────────
REASON=$(cat <<EOF
This Edit/Write targets a file that is NOT in the active scope manifest:

  Target:    $REL_PATH
  Manifest:  ${SCOPE_FILE#"$PROJECT_ROOT"/}
  Project:   $PROJECT_ROOT

The change-scope discipline (docs/change-scope-discipline.md, bundled) requires that
scope-manifest edits PRECEDE any out-of-scope code edits — scope-before-code for
mid-change expansion.

YOU HAVE THREE PATHS:

1. ADD the file to the scope manifest (intentional scope expansion).
   • Edit ${SCOPE_FILE#"$PROJECT_ROOT"/}; add a bullet for $REL_PATH with a one-line rationale.
   • This Edit/Write will then be allowed (manifest mtime within $SCOPE_RECENT_WINDOW-second grace window).

2. ADD the file to .scope-ignore (auto-generated / vendored / out-of-discipline file).
   • Edit $PROJECT_ROOT/.scope-ignore; add the path (gitignore-style pattern).

3. BYPASS for a legitimate exception (audit-logged):
   • Set SCOPE_BYPASS_REASON env var: SCOPE_BYPASS_REASON="<one-line reason>"
   • The bypass logs to ~/.claude/log/scope-bypasses.jsonl for audit.
   • Use sparingly. Sustained bypass = the discipline isn't right for this case; refine the rule, don't silence it.

If you genuinely believed this file was in scope, recheck the manifest — the bullet may be missing or the path may not match the glob pattern you wrote.
EOF
)

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'

exit 0
