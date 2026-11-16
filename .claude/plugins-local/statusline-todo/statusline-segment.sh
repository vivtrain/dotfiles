#!/usr/bin/env bash
# Status-line segment for the statusline-todo plugin.
# Usage: statusline-segment.sh <session_id>
# Prints the session's todo list, one item per line, each line starting with "\n" so it can be
# appended to whatever the status line has printed so far. Prints nothing when the list is empty.
#   done:     green bold ✔ (U+2714), then the text
#   not done: ☐ (U+2610), then the text
# Text stays in the terminal's regular style.

sid=$1
[ -n "$sid" ] || exit 0
file=${XDG_CACHE_HOME:-$HOME/.cache}/claude-todos/$sid.txt
[ -s "$file" ] || exit 0

ltrim() { local s=$1; printf '%s' "${s#"${s%%[![:space:]]*}"}"; }

while IFS= read -r line || [ -n "$line" ]; do
  line=$(ltrim "$line")
  [ -n "$line" ] || continue
  case $line in
    '[x]'* | '[X]'*) printf '\n\e[1;32m✔\e[0m %s' "$(ltrim "${line:3}")" ;;
    '[ ]'*)          printf '\n☐ %s' "$(ltrim "${line:3}")" ;;
    '[]'*)           printf '\n☐ %s' "$(ltrim "${line:2}")" ;;
    *)               printf '\n☐ %s' "$line" ;;
  esac
done < "$file"
exit 0
