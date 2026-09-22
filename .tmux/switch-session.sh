#!/bin/sh
# Switch client $2 to the $1-th session (1-based), ordered by creation, so
# numbering stays gapless when sessions are killed. Errors go to the status
# line; always exit 0 so run-shell doesn't take over the pane.
msg() {
    # display-message -c is broken in tmux 3.2a, so target the client's pane
    pane=$(tmux list-clients -F '#{client_name} #{pane_id}' | awk -v c="$2" '$1 == c { print $2 }')
    tmux display-message ${pane:+-t "$pane"} "$1"
}
id=$(tmux list-sessions -F '#{session_id}' | tr -d '$' | sort -n | sed -n "${1}p")
if [ -z "$id" ]; then
    msg "No session $1" "$2"
elif ! err=$(tmux switch-client -c "$2" -t "\$$id" 2>&1); then
    msg "$err" "$2"
fi
exit 0
