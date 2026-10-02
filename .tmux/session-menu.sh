#!/bin/sh
# Show a menu of sessions with the current one ($1) marked with a leading icon
# and preselected via display-menu -C (tmux 3.4+). Sessions are ordered by
# creation (session_id) to match switch-session.sh. Pass "mouse" as $2 when
# opened from a click: the menu then handles the mouse (-M) and stays open until
# a click (-O), but tmux ignores -C for mouse menus so nothing is preselected.
cur=$1
flags=''
[ "$2" = mouse ] && flags='-M -O'
mark=''
list=$(tmux list-sessions -F '#{session_id} #S' | tr -d '$' | sort -n)
set --
n=0
sel=0
while read -r id s; do
    label="  $s"
    if [ "$s" = "$cur" ]; then
        label="#[fg=green]$mark#[default] $s"
        sel=$n
    fi
    n=$((n + 1))
    set -- "$@" "$label" "$n" "switch-client -t \$$id"
done <<EOF2
$list
EOF2
tmux display-menu $flags -C "$sel" -S fg=cyan -H bg=#1e4d2b,fg=#ffffff -b rounded -T "#[fg=cyan]#[bg=cyan,fg=black,bold]Switch Sessions#[bg=default,fg=cyan,nobold]" "$@"
