#!/usr/bin/env bash
# Open handler for file:///tmux/<session>:<window>.<pane> links: switch the most recently
# active tmux client to that pane. Wired up in ~/.config/kitty/open-actions.conf.
target=${1#file:///tmux/}
target=$(printf '%b' "${target//%/\\x}")   # undo percent-encoding (e.g. %7E for ~)
client=$(tmux list-clients -F '#{client_activity} #{client_name}' | sort -n | tail -1 | cut -d' ' -f2)
tmux switch-client ${client:+-c "$client"} -t "$target" \; select-window -t "$target" \; select-pane -t "$target"
