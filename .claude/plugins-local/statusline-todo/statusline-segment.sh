#!/usr/bin/env bash
# Status-line segment for the statusline-todo plugin.
# Usage: statusline-segment.sh <session_id>
# Prints the session's todo list, one item per line, each line starting with "\n" so it can be
# appended to whatever the status line has printed so far. Prints nothing when the list is empty.
# Glyphs are the Nerd Font Material outline checkbox set:
#   [x] done:    green bold 󰄵 (md-checkbox_marked_outline U+F0135)
#   [!] failed:  red bold 󰅘 (md-close_box_outline U+F0158)
#   [~] partial: yellow bold 󰛲 (md-minus_box_outline U+F06F2)
#   [ ] open:    󰄱 (md-checkbox_blank_outline U+F0131)
# Text stays in the terminal's regular style. A markdown link [text](url) in an item renders as
# an OSC 8 hyperlink showing only its text.

sid=$1
[ -n "$sid" ] || exit 0
file=${XDG_CACHE_HOME:-$HOME/.cache}/claude-todos/$sid.txt
[ -s "$file" ] || exit 0

# [text](url) -> OSC 8 hyperlink.
linkify() { sed -E 's/\[([^][]*)\]\(([^)]*)\)/\x1b]8;;\2\x1b\\\1\x1b]8;;\x1b\\/g'; }

ltrim() { local s=$1; printf '%s' "${s#"${s%%[![:space:]]*}"}"; }

while IFS= read -r line || [ -n "$line" ]; do
  line=$(ltrim "$line")
  [ -n "$line" ] || continue
  case $line in
    '[x]'* | '[X]'*) printf '\n\e[1;32m󰄵\e[0m %s' "$(ltrim "${line:3}")" ;;
    '[!]'*)          printf '\n\e[1;31m󰅘\e[0m %s' "$(ltrim "${line:3}")" ;;
    '[~]'*)          printf '\n\e[1;33m󰛲\e[0m %s' "$(ltrim "${line:3}")" ;;
    '[ ]'*)          printf '\n󰄱 %s' "$(ltrim "${line:3}")" ;;
    '[]'*)           printf '\n󰄱 %s' "$(ltrim "${line:2}")" ;;
    *)               printf '\n󰄱 %s' "$line" ;;
  esac
done < "$file" | linkify
exit 0
