#!/usr/bin/env bash
# Intellectual Honesty Discipline Reminder — UserPromptSubmit hook
#
# Fires when the user's message contains debugging / diagnosis / decision-making
# vocabulary. Injects a reminder to (a) verify technical claims about external
# systems with tool calls before stating, and (b) push back with reasoning when
# the user's proposal has a known failure mode, not rubber-stamp agreement, and
# (c) trace upstream before reaching for an SDK-level band-aid.
#
# Why: confident-wrong claims about external system behavior erode trust. Tool
# calls take 30s; the cost of an unverified wrong claim is higher. Reflexive
# agreeableness is a separate failure mode sharing the same root — prioritizing
# conversation flow over accuracy.
#
# Triggers (case-insensitive): debugging/diagnosis vocab, proposal/decision
# vocab, OR band-aid/SDK-throw vocab. Any prong fires (OR, not AND).
#
# Failure mode: silent exit 0 on any error. Never block prompt submission.

set -u

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
if [ -z "$PROMPT" ]; then
  exit 0
fi

PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

FIRE=0

# Debugging / diagnosis / investigation vocab — where speculation hurts most
case "$PROMPT_LC" in
  *"why is"*|*"why isn't"*|*"why does"*|*"why doesn't"*|*"why was"*|*"why are"*) FIRE=1 ;;
  *"what's wrong"*|*"what is wrong"*|*"what broke"*|*"what's broken"*) FIRE=1 ;;
  *"debug"*|*"investigate"*|*"diagnose"*|*"diagnosis"*) FIRE=1 ;;
  *"root cause"*|*"the cause"*|*"the issue is"*|*"find the issue"*) FIRE=1 ;;
  *"why did"*|*"how come"*|*"figure out"*|*"figure it out"*) FIRE=1 ;;
  *"check why"*|*"see why"*|*"understand why"*) FIRE=1 ;;
esac

# Proposal / architecture / decision vocab — where agreeableness hurts most
case "$PROMPT_LC" in
  *"should we"*|*"what if we"*|*"can we"*|*"how about"*|*"what about"*) FIRE=1 ;;
  *"let's "*|*"i think we should"*|*"i want to"*|*"i'm going to"*) FIRE=1 ;;
  *"is it better"*|*"would it be better"*|*"is that right"*|*"does that make sense"*) FIRE=1 ;;
  *"thoughts?"*|*"your thoughts"*|*"any thoughts"*) FIRE=1 ;;
esac

# Band-aid / SDK-throw vocab — where verify-before-band-aid hurts most.
case "$PROMPT_LC" in
  *"sdk throws"*|*"sdk throw"*|*"sdk is throw"*|*"sdk error"*|*"sdk is erroring"*) FIRE=1 ;;
  *"error from"*|*"errors from"*) FIRE=1 ;;
  *"the library is"*|*"the library throws"*|*"the library errors"*) FIRE=1 ;;
  *"workaround for"*|*"workaround to"*|*"work around"*) FIRE=1 ;;
  *"force-"*|*"force flag"*|*"force long"*|*"force disable"*) FIRE=1 ;;
esac

if [ "$FIRE" = "0" ]; then
  exit 0
fi

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "INTELLECTUAL HONESTY DISCIPLINE REMINDER. THREE disciplines apply: (1) SPECULATION: Before stating any technical fact about external systems (third-party APIs, CLI/tool internals, OS behavior, plugins, library behavior), either VERIFY with a tool call first (Bash probe, WebFetch on docs, grep, ps, etc.) OR explicitly frame as speculation ('I think X but haven't verified — recommend checking'). Never assert as fact without verification. Tool calls take 30s — cost of an unverified wrong claim is higher. If the user corrects a claim, don't immediately make another speculative claim in the same response. (2) DISAGREEMENT: When the user proposes an approach/architecture/name/decision, EVALUATE it before agreeing. Push back with reasoning when: (a) it violates a previously-locked decision, (b) it has a known failure mode, (c) it's over-engineered for the actual need (propose simpler first), (d) the reasoning has a logical gap, or (e) you'd recommend differently if it were your call. NOT contrarianism — being a useful interlocutor. Lead with the reasoning, stay specific, steelman first. Don't open with 'Great question!' filler. Don't bury concerns in a second-to-last paragraph. Don't agree first then hedge. If you don't have enough context to push back, ASK — don't speculate. (3) VERIFY-BEFORE-BAND-AID: When a library/SDK/API surfaces an error, the first hypothesis must be 'what did we hand it / what state is it in?' NOT 'what flag turns this off?'. Trace back to inputs and initialization before reaching for SDK-level workarounds (transport flags, retry wrappers, force-polling, polyfills, version pins). The library is usually telling the truth about a violated invariant; the defect is often upstream (auth state, payload shape, init order, dev affordances leaking into prod paths). Plausible-but-unverified compatibility narratives are exactly the shape band-aids hide behind — before shipping a workaround, run the falsifying test. All three failure modes share a root: prioritizing flow over accuracy. Spend the 30s, accept the friction, earn trust through accuracy not smoothness."
  }
}
EOF

exit 0
