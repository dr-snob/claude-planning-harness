#!/usr/bin/env bash
# completion-claim-checkbox-guard — Stop hook.
#
# THE RULE: the agent must not SAY a plan/workstream is "complete / done / fully
# wired" while that plan still has unchecked `**N.M**` checkboxes.
#
# Mechanism: on Stop, read the agent's LAST message. Two claim kinds:
#   • PLAN-LEVEL ("the plan is complete", "everything done") → BLOCK if ANY
#     active (non-archive) .planning/<plan>/plan.md has unchecked `**N.M**` boxes
#     (excluding the human-owned **99.0**).
#   • PER-PHASE ("phase 4 complete") → BLOCK if PHASE 4's own `**4.M**` boxes are
#     unchecked. Scoped to the claimed phase so legitimately-unfinished LATER
#     phases mid-plan don't false-positive.
# Either way the block forces the agent to check the boxes (if truly done) or
# correct its claim before ending the turn.
#
# KNOWN LIMITATION: this reads the agent's CHAT message, not commit messages.
#
# Loop-safe: `stop_hook_active` short-circuits (no infinite re-block). Fail-open.
# Companion to plan-complete-flip-guard.sh (which gates the **99.0** flip itself).

set -u
INPUT=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0

# Loop guard: if we're already continuing from a previous Stop-block, don't re-fire.
ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$ACTIVE" = "true" ] && exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] || CWD=$(pwd)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

PLAN_DIR="$CWD/.planning"
[ -d "$PLAN_DIR" ] || exit 0

# Last assistant message text from the transcript (JSONL).
LAST=$(jq -rs '
  map(select(.type=="assistant" or .role=="assistant")) | last //empty
  | (.message.content // .content // empty)
  | if type=="array" then (map(.text // empty) | join("\n")) else (.|tostring) end
' "$TRANSCRIPT" 2>/dev/null)
[ -n "$LAST" ] || exit 0

# Completion claim? Two kinds, handled differently:
#   PLAN-LEVEL ("the plan is complete", "everything done") → check ALL boxes.
#   PER-PHASE  ("phase 4 complete")                        → check ONLY phase 4's
#     boxes (scoping removes the unfinished-later-phase false-positive).
PLAN_LEVEL=0
PHASE_N=""
if printf '%s' "$LAST" | grep -qiE 'plan (is )?(now )?complete|fully complete|workstream complete|wave[ -][0-9]* (is )?complete|everything (is )?(done|complete|wired)|all (gaps|boxes|phases|items) (are )?(fixed|done|complete)|marking .*(complete|done)|✅ *(complete|done)|is complete\b'; then
  PLAN_LEVEL=1
else
  # Per-phase claim — "phase N (is/now) complete|done|finished|shipped|wrapped",
  # or "complete: phase N", or "✅ phase N". Extract the phase integer.
  PHASE_CLAIM=$(printf '%s' "$LAST" | grep -ioE 'phase[ -]?[0-9]+( is| now)? (complete|completed|done|finished|shipped|wrapped)|(complete|completed|done|finished)[: ]+phase[ -]?[0-9]+|✅[ ]*phase[ -]?[0-9]+|marking phase[ -]?[0-9]+ (as )?(complete|done)' | head -1)
  PHASE_N=$(printf '%s' "$PHASE_CLAIM" | grep -oE '[0-9]+' | head -1)
fi
# No completion claim of either kind → nothing to guard.
[ "$PLAN_LEVEL" = "1" ] || [ -n "$PHASE_N" ] || exit 0

# SUPPRESS on an HONEST status report / denial — the failure to catch is a BLIND
# completion claim, NOT an honest "nothing is complete, here's what's open." If the
# message already acknowledges incompleteness/open work, the agent is doing the right
# thing → don't block.
printf '%s' "$LAST" | grep -qiE "not (yet )?(complete|done|finished)|n't (complete|done|finished)|nothing is (complete|done)|incomplete|not finished|still (open|has|have|pending)|(boxes|steps|items|phases|box|work) (are )?(still )?open|open (box|boxes|step|steps|item|items)|unchecked|remaining|won't call|will not call|isn't (complete|done|finished)|are (still )?open|stays open|left to do" && exit 0

# Any active (non-archive) plan with unchecked boxes (excluding **99.0**)?
# Scope the box pattern: plan-level claim → ALL **N.M**; per-phase claim →
# ONLY that phase's **<PHASE_N>.M**.
if [ -n "$PHASE_N" ]; then
  BOX_RE="^[[:space:]]*-[[:space:]]*\[ \][[:space:]]*\*\*${PHASE_N}\.[0-9]+\*\*"
else
  BOX_RE='^[[:space:]]*-[[:space:]]*\[ \][[:space:]]*\*\*[0-9]+\.[0-9]+\*\*'
fi
UNCHECKED=""
for pm in "$PLAN_DIR"/*/plan.md; do
  [ -f "$pm" ] || continue
  case "$pm" in */archive/*) continue ;; esac
  hits=$(grep -nE "$BOX_RE" "$pm" 2>/dev/null \
         | grep -vE '\*\*99\.0\*\*' || true)
  [ -n "$hits" ] || continue
  name=$(basename "$(dirname "$pm")")
  n=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')
  first=$(printf '%s\n' "$hits" | head -3 | sed -E 's/^[0-9]+:[[:space:]]*/      /')
  UNCHECKED="${UNCHECKED}
  • ${name}: ${n} unchecked step(s), e.g.
${first}"
done

[ -n "$UNCHECKED" ] || exit 0

SCOPE_NOTE="active plan(s)"
[ -n "$PHASE_N" ] && SCOPE_NOTE="Phase ${PHASE_N}"
REASON="COMPLETION CLAIM vs UNCHECKED BOXES. Your message claims completion of ${SCOPE_NOTE}, but these **N.M** steps are still unchecked:${UNCHECKED}

Before ending the turn:
  1. If the work IS done → CHECK those boxes in plan.md now, and run the plan's self-review checklist.
  2. If it is NOT done → correct your message: say what's actually complete vs open, do NOT call the plan/workstream 'complete'.
  3. The final **99.0** stays the human's to flip — never flip it yourself.
Don't declare done while boxes are open — that is the self-scoped-'done' failure this exists to stop."

jq -n --arg r "$REASON" '{ decision: "block", reason: $r }'
exit 0
