#!/bin/sh
# Show a menu of sessions, marking the current one ($1) with '*'. tmux 3.2a's
# display-menu has no -C to preselect an item (added in 3.4), so mark it instead.
# Sessions are ordered by creation (session_id) to match switch-session.sh.
cur=$1
list=$(tmux list-sessions -F '#{session_id} #S' | tr -d '$' | sort -n)
set --
n=0
while read -r id s; do
    n=$((n + 1))
    label=$s
    [ "$s" = "$cur" ] && label="$s *"
    set -- "$@" "$label" "$n" "switch-client -t \$$id"
done <<EOF
$list
EOF
tmux display-menu -T " Switch Sessions " "$@"
