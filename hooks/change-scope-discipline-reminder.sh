#!/usr/bin/env bash
# Change Scope Discipline Reminder — PreToolUse hook on Bash w/ git commit
#
# Fires when the agent is about to run `git commit`. Injects the diff-audit
# ritual reminder so the agent runs a hunk-by-hunk scope check against
# baseline before the commit lands. Advisory, non-blocking.
#
# Source: docs/change-scope-discipline.md (bundled with this plugin).
#
# Why: collateral drift compounds invisibly across commits — small unintended
# mutations (autoformat, "while I'm here" creep, script overreach) accumulate
# until the code is structurally different from baseline without anyone
# consciously deciding. Diff-against-baseline audit at commit time is the
# detection layer; this hook is the memory aid that ensures the audit runs.
#
# Trigger: tool=Bash AND command contains "git commit" (case-insensitive).
#
# Failure mode: silent exit 0 on any error. Never block tool execution.

set -u

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$TOOL_NAME" = "Bash" ] || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0

CMD_LC=$(printf '%s' "$CMD" | tr '[:upper:]' '[:lower:]')
case "$CMD_LC" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "CHANGE SCOPE DISCIPLINE — pre-commit audit. Before committing: (1) run `git diff --staged` hunk-by-hunk; for every hunk ask 'is this in the stated scope?' If no -> restore (`git restore --staged --worktree -p <file>`). (2) For a branch/PR, audit the cumulative diff against the base branch (`git diff <base>...HEAD`), not just the last commit — drift compounds across commits. (3) Don't trust build-green + tests-green as proof of correctness; a mass-mutation script can pass every automated signal and still have overreached. Full guidance: docs/change-scope-discipline.md (bundled). Pre-edit accountability is enforced separately by change-scope-pre-edit-gate.sh — this hook is the commit-time audit reminder."
  }
}
EOF

exit 0
