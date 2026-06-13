#!/usr/bin/env bash
# Secrets Discipline Reminder — UserPromptSubmit hook
#
# Fires when the user's message references secrets, tokens, credentials, or
# uploads screenshots/recordings likely to contain dashboard pages with secret
# values visible. Emits a reminder to NOT echo secret values back in chat text,
# reference by name only, and clean up local artifacts.
#
# Why: once a secret value lands in a chat transcript, rotation — not deletion —
# is the only fix (the transcript may be retained). Surface the discipline
# BEFORE the slip-up: typing a value into a reminder/example, OCR-quoting a
# value visible in a screenshot, or extracting a video frame showing a secret.
#
# Triggers (case-insensitive): secret-vocabulary words, image/video file refs
# that suggest dashboard captures, OAuth/auth flow language.
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

# Secret / credential vocabulary
case "$PROMPT_LC" in
  *"secret"*|*"token"*|*"password"*|*"credential"*|*"api key"*|*"app key"*) FIRE=1 ;;
  *"rotate"*|*"revoke"*|*"regenerate"*|*"app secret"*|*"client secret"*) FIRE=1 ;;
  *"access token"*|*"verify token"*|*"client token"*|*"oauth"*|*"jwt"*) FIRE=1 ;;
  *"private key"*|*"signing key"*|*"webhook secret"*|*".env"*) FIRE=1 ;;
  *"hmac"*|*"signature"*|*"bearer "*) FIRE=1 ;;
esac

# Media file paths likely to show dashboards (and visible secret values)
case "$PROMPT_LC" in
  *"screenshot"*|*"screen recording"*|*"screencapture"*) FIRE=1 ;;
  *"/desktop/"*|*"/downloads/"*|*"temporaryitems"*) FIRE=1 ;;
esac

if [ "$FIRE" = "0" ]; then
  exit 0
fi

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "SECRETS DISCIPLINE REMINDER: This prompt references secrets, credentials, or media that may show secret values. (1) NEVER echo or quote secret values back in chat text — reference by NAME only ('the VERIFY_TOKEN you saved', 'the App Secret from the settings page'). (2) When viewing screenshots / screen recordings: scan for visible secret-shaped strings (hex strings >=32 chars, sk_*, gho_*, AKIA*, eyJ* JWTs, App Secret fields, Client Token, Access Token, Verify Token, .env contents) BEFORE describing the content. If you spot one, describe context without quoting the value — say 'the App Secret was visible' not 'the App Secret is abc123...'. (3) Clean up local artifacts (extracted video frames, debug dumps, temp files containing secret-shaped strings) at end of investigation via `rm -rf /tmp/<dir>/`. (4) Chat transcripts may be retained. Values that land in chat require rotation, not deletion. Treat the chat as a publication, not a private notepad. (5) Memory/notes entries: never store secret values, only references / categories / lessons. (6) When suggesting curl commands, prefer `read -s VAR` silent prompts so values stay out of shell history AND chat transcript: `read -s TOK; curl -sG ... --data-urlencode \"access_token=$TOK\"; unset TOK`."
  }
}
EOF

exit 0
