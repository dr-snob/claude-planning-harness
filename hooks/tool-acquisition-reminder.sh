#!/usr/bin/env bash
# Tool Acquisition Reminder — UserPromptSubmit hook
#
# Fires when the user's message references a file format or capability verb
# that commonly tempts a naive "I can't view/read/process X" response.
# Emits a reminder to reach for `brew` / `pip3` / shell BEFORE saying "I can't".
#
# Why: silent-incapability claims waste user round-trips. The discipline is
# probe -> install -> use, with permission-free autonomy for free user-scoped
# installs (Homebrew, pip --user, npm global).
#
# Triggers (case-insensitive): file extensions for media, archives, office
# docs, design files, audio, plus a handful of capability verbs.
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
case "$PROMPT_LC" in
  # Video
  *.mov*|*.mp4*|*.mkv*|*.webm*|*.avi*|*.m4v*|*.wmv*|*.flv*) FIRE=1 ;;
  # Audio
  *.wav*|*.mp3*|*.flac*|*.aac*|*.m4a*|*.ogg*|*.opus*) FIRE=1 ;;
  # Raw / camera images
  *.heic*|*.heif*|*.raw*|*.arw*|*.cr2*|*.cr3*|*.nef*|*.dng*|*.orf*|*.rw2*) FIRE=1 ;;
  # Design / vector
  *.psd*|*.ai*|*.sketch*|*.fig*|*.xd*|*.indd*|*.svg*|*.eps*) FIRE=1 ;;
  # Office / publishing
  *.docx*|*.doc*|*.xlsx*|*.xls*|*.pptx*|*.ppt*|*.epub*|*.mobi*|*.azw3*|*.rtf*|*.odt*|*.ods*) FIRE=1 ;;
  # Archives
  *.zip*|*.tar.gz*|*.tgz*|*.7z*|*.rar*|*.dmg*|*.pkg*|*.iso*|*.bz2*|*.xz*) FIRE=1 ;;
  # 3D / CAD
  *.stl*|*.obj*|*.blend*|*.glb*|*.gltf*|*.fbx*|*.dwg*|*.dxf*|*.step*|*.stp*) FIRE=1 ;;
  # Fonts
  *.ttf*|*.otf*|*.woff*|*.woff2*) FIRE=1 ;;
  # Notebooks / data
  *.parquet*|*.feather*|*.h5*|*.hdf5*|*.arrow*|*.duckdb*) FIRE=1 ;;
  # Capability verbs that often trigger "I can't"
  *"convert this"*|*"convert the"*|*"extract from"*|*"extract the audio"*|*"extract a frame"*|*"frames from"*|*"transcribe "*|*"ocr "*|*"render this"*|*"render the"*) FIRE=1 ;;
  *"watch this"*|*"watch the recording"*|*"see the recording"*|*"see this recording"*|*"play this"*) FIRE=1 ;;
  *) ;;
esac

if [ "$FIRE" = "0" ]; then
  exit 0
fi

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "TOOL ACQUISITION REMINDER: The user's message references a file format or capability that commonly triggers a naive \"I can't view/read/process X\" response. DO NOT do that. Order of operations: (1) PROBE — `command -v <tool>` / `brew info <pkg>` / `pip3 show <pkg>` (one Bash call); (2) IF PRESENT — use it immediately, no preface, no narration of limits; (3) IF ABSENT — install autonomously via `brew install` / `pip3 install --user` / `npm i -g` (no permission ceremony for free user-scoped installs), then use it; (4) ONLY claim inability after acquisition is attempted AND fails with a cited error. Common patterns: .mov/.mp4 -> ffmpeg extract frame -> Read PNG; .heic -> sips -s format png; .docx/.xlsx -> pandoc or python openpyxl; .pdf -> pdftotext or Read with pages; audio/video transcript -> whisper. Search first to confirm, then either install or use what exists. Don't ask permission for free scoped installs; do them and mention what you did."
  }
}
EOF

exit 0
