#!/bin/sh
# Session order shared by session-menu.sh and switch-session.sh.
#   session-order.sh list           print "<id> <name>" per session (id without '$'), in order
#   session-order.sh move -1|+1 ID  move session ID up/down one place and flash the new order
# The order lives in each session's @order option. Sessions without one (new
# ones) sort after the rest, by creation, so the default is creation order.
list() {
    tmux list-sessions -F '#{session_id} #{?#{@order},#{@order},x} #S' | tr -d '$' |
        awk '{ k = ($2 == "x" ? 1000000 + $1 : $2); $2 = ""; sub(/  /, " "); print k, $0 }' |
        sort -n | cut -d' ' -f2-
}
case $1 in
list) list ;;
move)
    id=${3#\$}
    # swap ID with its neighbour, then renumber every session 1..n
    ids=$(list | cut -d' ' -f1 | awk -v id="$id" -v d="$2" '
        { a[NR] = $1; if ($1 == id) p = NR }
        END { q = p + d; if (p && q >= 1 && q <= NR) { t = a[p]; a[p] = a[q]; a[q] = t }
              for (i = 1; i <= NR; i++) print a[i] }')
    n=0
    for i in $ids; do
        n=$((n + 1))
        tmux set-option -t "\$$i" @order "$n"
    done
    # flash the order on the message line (message-style colours), the moved
    # session as a reversed powerline segment, the rest split by thin arrows
    msg=$(list | awk -v id="$id" -v arrow="$(printf '\356\202\260')" -v thin="$(printf '\356\202\261')" '
        BEGIN { printf "Sessions: " }
        { n = $1; $1 = ""; sub(/^ /, "")
          if (n == id) printf "#[fg=#081f4d,bg=#ffffff]%s#[bold] %d %s #[nobold,fg=#ffffff,bg=#081f4d]%s", arrow, NR, $0, arrow
          else printf "%s %d %s ", (NR > 1 && !moved ? thin : ""), NR, $0
          moved = (n == id) }')
    tmux display-message -d 1500 "$msg"
    ;;
esac
