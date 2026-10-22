#!/bin/sh
# Switch client $2 to the $1-th session (1-based), in session-order.sh order, so
# numbering stays gapless when sessions are killed. Errors go to the status
# line; always exit 0 so run-shell doesn't take over the pane.
msg() {
    tmux display-message -c "$2" "$1"
}
id=$(~/.tmux/session-order.sh list | sed -n "${1}p" | cut -d' ' -f1)
if [ -z "$id" ]; then
    msg "No session $1" "$2"
elif ! err=$(tmux switch-client -c "$2" -t "\$$id" 2>&1); then
    msg "$err" "$2"
fi
exit 0
