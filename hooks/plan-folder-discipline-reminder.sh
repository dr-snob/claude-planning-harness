#!/usr/bin/env bash
# Plan-Folder Discipline Reminder — PostToolUse hook
#
# Enforces the .planning folder convention mechanically by emitting reminders when:
#
#   1. Agent writes a `*/.planning/<plan>/plan.md` and one of the authored sibling
#      files (scope.md, resume-next-session.md) is missing.
#      → Completeness reminder.
#
#   2. Agent writes a `*/.planning/<plan>/resume-next-session.md` (per-plan).
#      → Routing reminder: "project-scoped, NOT for sidequest carries —
#         those go in the global .planning/resume-next-session.md instead."
#
#   3. Agent writes a `*/.planning/resume-next-session.md` (global, flat root).
#      → Routing reminder: "global, NOT for plan-specific content — that
#         goes in .planning/<plan>/resume-next-session.md instead."
#
# Convention spec: docs/planning-folder-format.md (bundled with this plugin).
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

# Quick filter: must be inside some `.planning/` somewhere
case "$FILE_PATH" in
  */.planning/*) ;;
  *) exit 0 ;;
esac

BASENAME=$(basename "$FILE_PATH")
PARENT=$(dirname "$FILE_PATH")
GRANDPARENT_NAME=$(basename "$PARENT")
GREATGRANDPARENT_NAME=$(basename "$(dirname "$PARENT")")

# Detect path shape:
#   $GREATGRANDPARENT_NAME == ".planning" → .planning/<plan>/<file> (subfolder)
#   $GRANDPARENT_NAME == ".planning"      → .planning/<file> (flat root)
#   neither → deeper (e.g. .planning/archive/<plan>/<file>), skip

SHAPE=""
if [ "$GREATGRANDPARENT_NAME" = ".planning" ]; then
  SHAPE="subfolder"
elif [ "$GRANDPARENT_NAME" = ".planning" ]; then
  SHAPE="root"
else
  exit 0
fi

# ── Concern 1: completeness check on subfolder plan.md ───────────────────
if [ "$SHAPE" = "subfolder" ] && [ "$BASENAME" = "plan.md" ]; then
  MISSING=()
  [ ! -f "$PARENT/scope.md" ]               && MISSING+=("scope.md")
  [ ! -f "$PARENT/resume-next-session.md" ] && MISSING+=("resume-next-session.md")

  if [ ${#MISSING[@]} -gt 0 ]; then
    MISSING_LIST=$(printf '%s, ' "${MISSING[@]}")
    MISSING_LIST=${MISSING_LIST%, }
    jq -n --arg file "$FILE_PATH" --arg missing "$MISSING_LIST" '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: ("PLAN-FOLDER DISCIPLINE REMINDER (see docs/planning-folder-format.md, bundled). A plan.md was just written at " + $file + " but the per-plan subfolder is missing required AUTHORED sibling file(s): " + $missing + ". Every per-plan subfolder needs the authored files — plan.md, scope.md, resume-next-session.md — created together (not deferred). Create the missing one(s) now in the SAME task: scope.md (the active phase scope manifest) + resume-next-session.md (project-scoped handoff placeholder). Skipping the authored files is the band-aid failure mode: defer-it-later means it never gets created.")
      }
    }'
    exit 0
  fi
fi

# ── Concern 2: per-plan resume-next-session.md routing reminder ───────────────
if [ "$SHAPE" = "subfolder" ] && [ "$BASENAME" = "resume-next-session.md" ]; then
  jq -n --arg file "$FILE_PATH" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("PLAN-FOLDER 2-TIER RESUME ROUTING REMINDER (see docs/planning-folder-format.md, bundled). You just wrote " + $file + " — this is a PROJECT-SCOPED handoff for one specific plan. It should contain ONLY context the next session needs to continue THIS plan: locked decisions for this rollout, current phase state, next action, gotchas specific to this work. DO NOT put here: out-of-scope sidequest carries, blocker fixes discovered during this rollout, observations about other plans, anything that does not belong to THIS rollout. Those belong in the GLOBAL handoff at the project'"'"'s .planning/resume-next-session.md instead. Re-read the content you just wrote and move any out-of-scope carries to the global resume file.")
    }
  }'
  exit 0
fi

# ── Concern 3: global resume-next-session.md routing reminder ─────────────────
if [ "$SHAPE" = "root" ] && [ "$BASENAME" = "resume-next-session.md" ]; then
  jq -n --arg file "$FILE_PATH" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("PLAN-FOLDER 2-TIER RESUME ROUTING REMINDER (see docs/planning-folder-format.md, bundled). You just wrote " + $file + " — this is the GLOBAL handoff at .planning/ root. It should contain ONLY out-of-scope sidequest carries, blocker fixes, and observations that do not belong to any active plan but the next session should see. DO NOT put here: continuation context for any specific in-flight plan, phase-state tracking for an active rollout, next-action for THIS plan'"'"'s work. Those belong in the PROJECT-SCOPED .planning/<plan>/resume-next-session.md instead. Re-read the content you just wrote and move any plan-specific context to the appropriate per-plan resume file.")
    }
  }'
  exit 0
fi

exit 0
