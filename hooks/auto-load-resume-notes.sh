#!/usr/bin/env bash
# Auto-load Resume Notes — SessionStart hook
#
# Fires when a new Claude session starts. Surfaces the project's resume handoff
# so the new session inherits context automatically.
#
# A project can have MULTIPLE resume files under .planning/ per the 2-tier
# convention — a GLOBAL one (.planning/resume-next-session.md, for out-of-scope
# sidequest carries) and PER-PLAN ones (.planning/<plan>/resume-next-session.md,
# the active-plan continuation). The global file goes stale because sidequest
# carries are written less often than active-plan handoffs, so blindly loading
# the global one misleads the next session. Instead PREFER the newest ACTIVE
# plan-scoped resume, falling back to the most-recently-edited resume overall.
# Other resume files are listed so nothing is hidden.
#
# Why a pointer not an inline dump: the harness caps inline hook additionalContext
# to a small preview. So emit a short pointer + a ~1 KB teaser and make the agent
# Read the full file (the Read tool path is uncapped).
#
# Failure mode: silent exit 0 on any error. Never block session start.

set -u

INPUT=$(cat 2>/dev/null || true)

# Determine project root. SessionStart input includes cwd if jq is present.
CWD=""
if command -v jq >/dev/null 2>&1 && [ -n "$INPUT" ]; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
fi
if [ -z "$CWD" ]; then
  CWD=$(pwd)
fi

# Prefer git repo root if inside a repo
if GIT_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null); then
  PROJECT_ROOT="$GIT_ROOT"
else
  PROJECT_ROOT="$CWD"
fi

PLAN_DIR="$PROJECT_ROOT/.planning"
if [ ! -d "$PLAN_DIR" ]; then
  exit 0
fi

# Need jq to emit JSON safely (handles escaping for content with quotes/newlines).
command -v jq >/dev/null 2>&1 || exit 0

# Collect every resume-next-session.md under .planning (skip archive), newest
# first by mtime. Supports both `stat -f %m` (BSD/macOS) and `stat -c %Y` (GNU).
SORTED=$(find "$PLAN_DIR" -name "resume-next-session.md" -not -path "*/archive/*" -type f 2>/dev/null \
  | while IFS= read -r f; do printf '%s\t%s\n' "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)" "$f"; done \
  | sort -rn)

[ -n "$SORTED" ] || exit 0

# 2-TIER PREFERENCE: PREFER an ACTIVE plan-scoped resume
# (.planning/<plan>/resume-next-session.md) over the GLOBAL pointer
# (.planning/resume-next-session.md), independent of mtime. The global file is a
# pointer + sidequest-carry store written less often, so it must NOT win an mtime
# race against the immediate plan-continuation handoff. "Active" = the plan is not
# 99.0-complete: a sibling plan.md carrying `[x] **99.0**` means the plan is done
# and its resume is stale, so skip it.
GLOBAL_RESUME="$PLAN_DIR/resume-next-session.md"
RESUME_FILE=""
while IFS= read -r line; do
  f=$(printf '%s' "$line" | cut -f2-)
  [ "$f" = "$GLOBAL_RESUME" ] && continue                 # global handled in fallback
  planmd="$(dirname "$f")/plan.md"
  if [ -f "$planmd" ] && grep -Eq '^[[:space:]]*-[[:space:]]*\[[xX]\][^\n]*\*\*99\.0\*\*' "$planmd"; then
    continue                                              # plan complete → resume is stale
  fi
  RESUME_FILE="$f"; break                                 # newest ACTIVE plan-scoped resume
done <<EOF
$(printf '%s\n' "$SORTED")
EOF

# Fall back to the newest resume overall (covers: global pointer, or a folder with
# no plan.md, or all-complete) if no active plan-scoped resume was found.
if [ -z "$RESUME_FILE" ]; then
  RESUME_FILE=$(printf '%s\n' "$SORTED" | head -1 | cut -f2-)
fi
[ -n "$RESUME_FILE" ] && [ -f "$RESUME_FILE" ] || exit 0

# Other resume files (relative paths), for visibility — everything except the chosen.
OTHERS=$(printf '%s\n' "$SORTED" | cut -f2- | grep -vxF "$RESUME_FILE" \
  | sed "s|^$PROJECT_ROOT/||" | sed 's/^/  - /')

SIZE_BYTES=$(wc -c < "$RESUME_FILE" | tr -d ' ')
SIZE_KB=$(( (SIZE_BYTES + 1023) / 1024 ))
TEASER=$(head -c 1200 "$RESUME_FILE")

OTHERS_NOTE=""
if [ -n "$OTHERS" ]; then
  OTHERS_NOTE=$(printf '\n\nOther resume files exist (older — consult only if relevant):\n%s' "$OTHERS")
fi

jq -n --arg teaser "$TEASER" --arg file "$RESUME_FILE" --arg kb "$SIZE_KB" --arg others "$OTHERS_NOTE" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("RESUME NOTES from the previous session: the chosen handoff is " + $file + " (~" + $kb + " KB). READ THE FULL FILE NOW with the Read tool before responding to the user — do NOT rely on the teaser below or on any preview; the teaser is only the first ~1 KB. The full file holds locked decisions, what is shipped, what is pending, user preferences, gotchas, and the do-not-do list. After reading it, proceed as if you were the previous session continuing; do NOT re-ask the user to re-explain anything in the notes." + $others + "\n\n--- TEASER (first ~1 KB — NOT the full notes; READ THE FILE) ---\n\n" + $teaser + "\n\n--- END TEASER — READ THE FULL FILE NOW ---")
  }
}'

exit 0
