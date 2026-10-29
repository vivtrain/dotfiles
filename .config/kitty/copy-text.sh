#!/usr/bin/env bash
# file:///copy/<percent-encoded text> links (open-actions.conf): copy the text instead of opening.
# Lets Claude print click-to-copy snippets: [text](file:///copy/text%20with%20spaces)
text=$(python3 -c 'import sys, urllib.parse
print(urllib.parse.unquote(sys.argv[1].removeprefix("file:///copy/")), end="")' "$1")
printf '%s' "$text" | xclip -selection clipboard
printf '%s' "$text" | xclip -selection primary
# Middle-click inside tmux pastes tmux's buffer, not the X primary selection.
tmux set-buffer -- "$text" 2>/dev/null
notify-send -t 1500 -a kitty "Copied" "${text:0:80}" 2>/dev/null
