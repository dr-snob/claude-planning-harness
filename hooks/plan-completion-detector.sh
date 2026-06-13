#!/usr/bin/env bash
# Plan Completion Detector — PostToolUse hook
#
# Fires when a plan.md is written/edited AND the designated final checkbox
# (carrying the `<!-- plan-complete-trigger -->` HTML marker) has been
# flipped to [x]. Idempotent via sidecar state files in
# ~/.claude/state/plan-completions/.
#
# Watches: any `*/.planning/<plan>/plan.md` (subfolder layout), and a
# `*/.planning/<ws>/scope.md` SCOPE-ONLY sidequest (no plan.md sibling).
#
# Convention spec: docs/planning-folder-format.md (bundled with this plugin),
# "Completion marker" section.
#
# Failure mode: silent exit 0 on any error. Never block tool execution.

set -u

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Care about the completion source inside the subfolder layout:
#   */.planning/<plan>/plan.md           — full plan
#   */.planning/<ws>/scope.md            — SCOPE-ONLY sidequest (no plan.md sibling)
# A scope-only sidequest carries the SAME `**99.0** ... <!-- plan-complete-trigger -->`
# line in its scope.md, so it gets the same completion->archive flow. Guard against
# a full plan's scope.md (which has no 99.0 anyway) by requiring NO plan.md sibling.
case "$FILE_PATH" in
  */.planning/*/plan.md) ;;
  */.planning/*/scope.md)
    [ -f "$(dirname "$FILE_PATH")/plan.md" ] && exit 0 ;;
  *) exit 0 ;;
esac

# File must exist (was just written)
[ ! -f "$FILE_PATH" ] && exit 0

# Find the completion checkbox. Require the DESIGNATED final-step ID **99.0**
# on the SAME line as the marker — NOT merely any checked line containing the
# marker substring. This defends against criteria / prose / code-spans that
# *quote* the marker to describe it. tail -1 keeps the last match if duplicated.
MARKER_LINE=$(grep -nE "^- \[[ xX]\] \*\*99\.0\*\* .*<!-- plan-complete-trigger -->" "$FILE_PATH" 2>/dev/null | tail -1)
[ -z "$MARKER_LINE" ] && exit 0  # No checkbox-shaped marker → plan not using the convention

# Extract content portion (after "linenum:")
LINE_CONTENT="${MARKER_LINE#*:}"

# Check for [x] or [X] checkbox state (case-insensitive)
case "$LINE_CONTENT" in
  *"- [x]"*|*"- [X]"*) ;; # checked → continue to fire
  *) exit 0 ;; # unchecked → silent
esac

# ── Idempotency: sidecar state file ──────────────────────────────────────
# Sidecar lives outside the project repo (~/.claude/state/) to keep plan
# folders clean. Unique per plan.md path via path-hash.
STATE_DIR="$HOME/.claude/state/plan-completions"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# sha256-based unique key per absolute plan.md path
if command -v shasum >/dev/null 2>&1; then
  HASH=$(printf '%s' "$FILE_PATH" | shasum -a 256 | cut -d' ' -f1)
elif command -v sha256sum >/dev/null 2>&1; then
  HASH=$(printf '%s' "$FILE_PATH" | sha256sum | cut -d' ' -f1)
else
  exit 0  # No hashing tool → can't guarantee idempotency, fail closed silently
fi

SIDECAR="$STATE_DIR/$HASH"
if [ -f "$SIDECAR" ]; then
  # Already notified for this plan.md path → silent (idempotent)
  exit 0
fi

# Write sidecar BEFORE emitting (avoid double-fire on retry)
PLAN_DIR=$(dirname "$FILE_PATH")
PLAN_NAME=$(basename "$PLAN_DIR")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
{
  echo "plan_path=$FILE_PATH"
  echo "plan_name=$PLAN_NAME"
  echo "notified_at=$TIMESTAMP"
} > "$SIDECAR"

# ── Emit the notification ────────────────────────────────────────────────
jq -n --arg name "$PLAN_NAME" --arg dir "$PLAN_DIR" --arg sidecar "$SIDECAR" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("🎉 PLAN COMPLETE — `" + $name + "` just had its `**99.0** Plan COMPLETE` checkbox flipped [x] (carries `<!-- plan-complete-trigger -->` marker). Suggested next step: move the folder to archive/ via these commands (single-quoted commit message): git mv " + $dir + " .planning/archive/" + $name + " && git commit -m '"'"'chore(planning): archive completed " + $name + "'"'"' && git push. Surface this to the user — they may want to verify nothing else needs cleanup before archiving. The completion sidecar at " + $sidecar + " makes this notification idempotent (re-edits of plan.md won'"'"'t re-fire). If this was a premature flip (false positive — bugs surfaced post-flip, follow-up work needed), unflip the checkbox in plan.md AND delete the sidecar file. Source: docs/planning-folder-format.md (bundled) Completion marker section.")
  }
}'

exit 0
