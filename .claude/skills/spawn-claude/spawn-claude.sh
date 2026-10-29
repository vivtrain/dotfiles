#!/usr/bin/env bash
# Open a new tmux window laid out like a normal working window:
#   left pane  = interactive bash with `claude` typed into it (so .bashrc loads,
#                CLAUDE_CODE_NO_FLICKER etc. apply, and exiting claude leaves a shell)
#   right pane = plain bash
# Prints the new claude pane as session:window.pane.
#
# Usage: spawn-claude.sh [-s session] [-d dir] [-n window-name] [-1] [-f] [-- claude args...]
#   -s  target tmux session (default: current session; created if it doesn't exist)
#   -d  working directory for both panes (default: $PWD)
#   -n  window name (default: tmux automatic naming)
#   -1  no split, just the claude pane
#   -f  switch to the new window (default: open in background)
#   anything after -- is passed to claude, e.g. -- "fix the flaky test"
set -euo pipefail

session="" dir="$PWD" name="" split=1 focus=0
while getopts "s:d:n:1fh" opt; do
    case $opt in
        s) session=$OPTARG ;;
        d) dir=$OPTARG ;;
        n) name=$OPTARG ;;
        1) split=0 ;;
        f) focus=1 ;;
        *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
    esac
done
shift $((OPTIND - 1))
[[ ${1:-} == -- ]] && shift

dir=$(realpath "$dir")
if [[ -z $session ]]; then
    [[ -n ${TMUX:-} ]] || { echo "not in tmux; pass -s <session>" >&2; exit 1; }
    session=$(tmux display -p '#S')
fi

args=(-d -c "$dir" -P -F '#{pane_id}')
[[ -n $name ]] && args+=(-n "$name")
if tmux has-session -t "=$session" 2>/dev/null; then
    pane=$(tmux new-window -t "$session:" "${args[@]}")
else
    pane=$(tmux new-session -s "$session" "${args[@]}")
fi

cmd=claude
for a in "$@"; do cmd+=" $(printf '%q' "$a")"; done

# One tmux round-trip for the rest. Typed keys queue in the pty until bash
# finishes .bashrc and reads them, so no need to wait for the prompt.
t=(send-keys -t "$pane" -l "$cmd" \; send-keys -t "$pane" Enter)
((split)) && t+=(\; split-window -d -h -t "$pane" -c "$dir")
((focus)) && [[ -n ${TMUX:-} ]] && t+=(\; switch-client -t "$pane")
t+=(\; display -p -t "$pane" '#S:#I.#P')
tmux "${t[@]}"
