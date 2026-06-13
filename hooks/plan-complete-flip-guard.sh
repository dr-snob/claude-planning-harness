#!/usr/bin/env bash
# plan-complete-flip-guard — PreToolUse(Edit|Write|MultiEdit) guard on the
# `**99.0** Plan COMPLETE` checkbox.
#
# THE RULE: an agent must NEVER flip a plan's final `**99.0**` checkbox from
# [ ] to [x] without the human's EXPLICIT, SPECIFIC word ("check the 99.0 box" /
# "mark it complete" / "flip 99.0"). Generic instructions — "complete the plan",
# "do the rest", "finish it", "wrap up Phase N" — DO NOT authorize it. The 99.0
# flip is the human-in-the-loop completion gate.
#
# Enforcement: block any Edit/Write/MultiEdit that flips 99.0 [ ]->[x], UNLESS
# the env var PLAN_COMPLETE_AUTHORIZED is set non-empty (the agent sets it ONLY
# in the turn the human explicitly authorized, quoting their words). Each bypass
# is appended to ~/.claude/log/plan-completion-authorizations.jsonl for audit.
#
# Fail-open on any internal error: never block an edit for the wrong reason.

set -u
INPUT=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

# Detect a flip to a CHECKED 99.0 marker (the plan-complete checkbox).
# Anchor to a REAL checkbox at line start, not a mid-line substring — else PROSE
# that mentions the rule (e.g. "lacks `[x] **99.0**`") in a plan/doc Write would
# be mis-detected as a flip and BLOCKED (a guardrail false-positive).
checked='^[[:space:]]*-[[:space:]]+\[[xX]\][^\n]*\*\*99\.0\*\*'
unchecked='^[[:space:]]*-[[:space:]]+\[ \][^\n]*\*\*99\.0\*\*'

flips=0
case "$TOOL" in
  Edit)
    OLD=$(printf '%s' "$INPUT" | jq -r '.tool_input.old_string // empty')
    NEW=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty')
    if printf '%s' "$OLD" | grep -Eq "$unchecked" && printf '%s' "$NEW" | grep -Eq "$checked"; then flips=1; fi
    ;;
  MultiEdit)
    # Any sub-edit that introduces a checked 99.0 where its old was unchecked.
    if printf '%s' "$INPUT" | jq -e '.tool_input.edits[]? | select((.old_string|test("(^|\\n)\\s*-\\s*\\[ \\][^\\n]*\\*\\*99\\.0\\*\\*")) and (.new_string|test("(^|\\n)\\s*-\\s*\\[[xX]\\][^\\n]*\\*\\*99\\.0\\*\\*")))' >/dev/null 2>&1; then flips=1; fi
    ;;
  Write)
    CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty')
    # Conservative: a Write producing a checked 99.0 marked with the completion trigger.
    if printf '%s' "$CONTENT" | grep -Eq "$checked" && printf '%s' "$CONTENT" | grep -q 'plan-complete-trigger'; then flips=1; fi
    ;;
esac

[ "$flips" -eq 0 ] && exit 0

# Authorized bypass path (audit-logged).
if [ -n "${PLAN_COMPLETE_AUTHORIZED:-}" ]; then
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // "?"' 2>/dev/null)
  LOG="$HOME/.claude/log/plan-completion-authorizations.jsonl"
  mkdir -p "$(dirname "$LOG")" 2>/dev/null
  printf '{"file":"%s","reason":"%s","tool":"%s"}\n' "$FILE" "${PLAN_COMPLETE_AUTHORIZED//\"/\'}" "$TOOL" >> "$LOG" 2>/dev/null
  exit 0
fi

REASON="BLOCKED: flipping **99.0** Plan COMPLETE requires the human's EXPLICIT word.

This edit flips a plan's final **99.0** checkbox to [x]. That is the human-in-the-loop
completion gate — only the human flips it, and only when they say so SPECIFICALLY
('check the 99.0 box' / 'mark it complete' / 'flip 99.0').

These do NOT authorize it: 'complete the plan', 'do the rest', 'finish it',
'wrap up Phase N', 'we're done'. If they haven't said the specific words, STOP and ASK.

If they DID explicitly authorize it this turn: set env PLAN_COMPLETE_AUTHORIZED to their
verbatim words and retry (the bypass is audit-logged). Do NOT set it on your own initiative."

jq -n --arg r "$REASON" '{
  hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r }
}'
exit 0
