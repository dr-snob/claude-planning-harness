#!/usr/bin/env bash
# Phase-Transition Checkbox Reminder — UserPromptSubmit hook
#
# Fires when the prompt signals moving to the next phase/step ("next phase",
# "what's next", "move on", "proceed", "go to the next", etc.) AND the project
# has a .planning/ folder. Reminds to mark the COMPLETED phase's checkboxes in
# plan.md BEFORE starting new work.
#
# Why: it is easy to ship a phase but forget to return to plan.md and tick its
# boxes. The phase-transition moment ("should we go to the next phase?") is
# exactly when to be reminded, because that's when the just-finished phase is
# about to be left behind unmarked.
#
# Bonus deterministic signal: flags any phase whose **N.0** summary box is still
# [ ] while ALL its **N.x** sub-steps are [x] (the "finished, forgot the summary"
# case). Done in node when available (macOS awk lacks 3-arg match).
#
# Failure mode: silent exit 0 on any error. Never blocks prompt submission.

set -u
INPUT=$(cat)

command -v jq >/dev/null 2>&1 || exit 0
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0
PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Move into the project dir so .planning/ resolves.
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

# ── Trigger vocab: phase / step transition ──────────────────────────────────
FIRE=0
case "$PROMPT_LC" in
  *"next phase"*|*"next step"*|*"next plan"*) FIRE=1 ;;
  *"what's next"*|*"whats next"*|*"what is next"*|*"what next"*) FIRE=1 ;;
  *"move on"*|*"moving on"*|*"proceed"*) FIRE=1 ;;
  *"go to the next"*|*"go on to"*|*"onto the next"*|*"on to the next"*) FIRE=1 ;;
  *"continue to the next"*|*"ready for the next"*|*"start the next"*) FIRE=1 ;;
  *"begin phase"*|*"start phase"*|*"begin the next"*) FIRE=1 ;;
esac
[ "$FIRE" = "0" ] && exit 0

# ── Only relevant where plans live ──────────────────────────────────────────
[ -d .planning ] || exit 0
PLANS=$(ls .planning/*/plan.md .planning/*-plan.md 2>/dev/null | grep -v '/archive/' || true)
[ -z "$PLANS" ] && exit 0

# ── Deterministic signal: **N.0** summary [ ] while all **N.x** sub-steps [x] ─
FINDINGS=""
if command -v node >/dev/null 2>&1; then
  FINDINGS=$(node -e '
const fs=require("fs");
const out=[];
for(const p of process.argv.slice(1)){
  let t; try{t=fs.readFileSync(p,"utf8")}catch(e){continue}
  const sum={}, sub={};
  for(const m of t.matchAll(/\[([ xX])\]\s+\*\*(\d+)\.(\d+)\*\*/g)){
    const c=m[1].toLowerCase()==="x", ph=m[2], st=m[3];
    if(st==="0") sum[ph]=c;
    else { (sub[ph]=sub[ph]||{d:0,o:0}); c?sub[ph].d++:sub[ph].o++; }
  }
  const f=Object.keys(sum).filter(ph=>!sum[ph]&&sub[ph]&&sub[ph].d>0&&sub[ph].o===0);
  if(f.length) out.push("    - "+p+": phase(s) "+f.join(", ")+" — all sub-steps [x] but **N.0** summary still [ ]");
}
process.stdout.write(out.join("\n"));
' $PLANS 2>/dev/null)
fi

FINDINGS_BLOCK=""
[ -n "$FINDINGS" ] && FINDINGS_BLOCK=" DETERMINISTIC FLAGS (summary box forgotten):\n${FINDINGS}\n"

# ── Emit reminder ───────────────────────────────────────────────────────────
MSG="PHASE-TRANSITION CHECKBOX REMINDER. You (or the user) signaled moving to the next phase/step. STOP before starting new work: did you mark the COMPLETED phase's checkboxes in the active .planning plan.md? The MD checkboxes are MANUAL and easy to forget. Verify: (1) the just-finished phase's **N.x** sub-step boxes are [x] AND the **N.0** summary box is [x] in plan.md; (2) any status table row reflects it; (3) commit the plan update. Only then proceed to the next phase. If nothing was completed this turn, ignore.${FINDINGS_BLOCK:+\n$FINDINGS_BLOCK}Active plan(s): $(printf '%s' "$PLANS" | tr '\n' ' ')"

# JSON-escape the message via jq.
jq -cn --arg msg "$MSG" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$msg}}'
exit 0
