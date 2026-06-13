#!/usr/bin/env bash
# End Session Handoff — UserPromptSubmit hook
#
# Fires when the user's message signals winding down ("wrap up", "end session",
# "let's stop", "save context", "handoff", "that's all for today", etc.) and
# injects a mandatory instruction for the agent to write a comprehensive handoff
# doc at <work-root>/.planning/resume-next-session.md BEFORE replying, so the next
# Claude session inherits full context.
#
# Why UserPromptSubmit (not Stop/SessionEnd): the instruction must land while the
# agent can still ACT on it. Stop fires on every turn-end (too noisy); SessionEnd
# is terminal (too late — nothing runs after). Gating on intent vocabulary in the
# prompt is the trigger that actually works.
#
# Failure mode: silent exit 0 on any error. Never block prompt submission.

set -u

INPUT=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0

PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0
PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Wind-down / handoff intent vocabulary.
FIRE=0
case "$PROMPT_LC" in
  *"end session"*|*"end the session"*|*"end of session"*|*"session over"*) FIRE=1 ;;
  *"wrap up"*|*"wrap this up"*|*"wrapping up"*|*"let's wrap"*) FIRE=1 ;;
  *"let's stop"*|*"let us stop"*|*"stopping for"*|*"stop for the day"*|*"stop here"*) FIRE=1 ;;
  *"that's all for"*|*"thats all for"*|*"done for the day"*|*"done for now"*|*"call it a day"*) FIRE=1 ;;
  *"save context"*|*"save the context"*|*"write the handoff"*|*"write a handoff"*|*"handoff"*|*"hand off"*) FIRE=1 ;;
  *"before we stop"*|*"before you stop"*|*"before we finish"*|*"wind down"*) FIRE=1 ;;
esac
[ "$FIRE" = "0" ] && exit 0

read -r -d '' MSG <<'EOF'
END SESSION HANDOFF REQUIRED — MANDATORY. You appear to be winding down. Before composing any other reply: (1) IDENTIFY THE WORK ROOT — the project where THIS SESSION'S WORK actually happened, which may DIFFER from the shell's launch cwd. Resolution order: (a) Look at recent Read/Edit/Write/Bash tool calls — if they predominantly touched files under one project root, USE THAT, even if the shell was launched elsewhere. (b) Within the chosen work root: prefer `git rev-parse --show-toplevel` if it's a git repo, else the directory itself. (c) Writing the handoff into a DIFFERENT project's repo than where the work happened would pollute that repo — the work root WINS over launch cwd. If genuinely ambiguous (work spanned multiple projects), ASK before writing. (2) Ensure `<work-root>/.planning/` exists (`mkdir -p`). (3) Write a comprehensive handoff at `<work-root>/.planning/resume-next-session.md` (overwrite if it exists — it's session-end state). It MUST include: <BIG PICTURE> what this project is; <LOCKED DECISIONS> non-negotiable choices made this session + rationale; <WHAT'S SHIPPED> concrete deliverables with file paths and any live URLs/IDs; <WHAT'S NOT YET BUILT> next-session backlog with specific specs; <USER PREFERENCES LEARNED> rules the user surfaced that future sessions must follow; <GOTCHAS / CAVEATS> technical bear-traps discovered this session the next session must NOT re-learn; <DON'T DO THIS LIST> abandoned paths the next session might re-suggest; <SUGGESTED ORDER OF OPERATIONS> for the next session's first 30 minutes; <COMMIT POINTERS> key commit hashes if relevant. (4) If the work root is a git repo: `git add` the file and commit (push if a remote exists). If not a git repo: write the file and note it's not git-tracked. (5) ONLY THEN reply with a tight summary of where things ended. Do not skip the file write — the file is the deliverable.
EOF

jq -n --arg msg "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $msg
  }
}'

exit 0
