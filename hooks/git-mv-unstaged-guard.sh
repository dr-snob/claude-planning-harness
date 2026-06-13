#!/usr/bin/env bash
# git-mv-unstaged-guard — PreToolUse(Bash) guard against the git-mv silent-loss footgun.
#
# THE FOOTGUN: `git mv <path>` of a file (or dir) that has UNSTAGED working-tree
# edits stages the rename using the OLD (HEAD) blob; your edits stay unstaged.
# A subsequent `git commit` commits only the staged (old) side and SILENTLY DROPS
# the edits. Git marks this as porcelain status `RM` (R=renamed in index,
# M=modified in worktree). This guard blocks `git commit` when that state exists.
#
# Scope: fires ONLY on `git commit`, and ONLY when a staged rename/copy ALSO has
# an unstaged worktree modification or deletion (status X in {R,C}, Y in {M,D}).
# A clean staged rename (Y = space) does NOT fire. Partial-staging of a normal
# (non-renamed) file does NOT fire. Tight pattern = low false-positive.
#
# Fail-open on any internal error: never block a commit for the wrong reason.

set -u

INPUT=$(cat 2>/dev/null || true)

command -v jq >/dev/null 2>&1 || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Only care about `git commit` invocations (not log/status/diff/etc.).
printf '%s' "$CMD" | grep -Eq '\bgit\b[^|;&]*\bcommit\b' || exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD=$(pwd)
git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Renamed/copied AND worktree-dirty: X in {R,C}, Y in {M,D}.
DANGER=$(git -C "$CWD" status --porcelain 2>/dev/null | grep -E '^[RC][MD] ' || true)
[ -z "$DANGER" ] && exit 0

FILES=$(printf '%s\n' "$DANGER" | sed -E 's/^[RC][MD] //' | sed 's/^/    /')

REASON="BLOCKED: git-mv silent-loss footgun.

The following are staged as RENAMES but also have UNSTAGED working-tree edits:
${FILES}

\`git mv\` staged the OLD content; your edits are UNSTAGED and would be LOST on this
commit (only the renamed-old blob is committed). This is the exact failure where a
rename 'succeeds' but the content change vanishes.

FIX: stage the edits before committing —
    git add <the file(s) above>
then re-run the commit. Verify with: git show :<newpath> | head   (must show your edits)."

jq -n --arg r "$REASON" '{
  hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r }
}'
exit 0
