#!/bin/sh
# Last/this/next month calendar. With no args (the status-right click) it is a
# menu of disabled rows, since menus close on a click outside (-M -O) and
# popups ignore those. With "key" (M-C) it is a popup running this script with
# "draw", which exits on any key so M-C closes it too; a menu would swallow M-C
# and only close on an item shortcut, which tmux always prints on the item.
# Month titles keep the cyan base style; weekdays are bright white, this month
# white with today in reversed cyan, and the neighbouring months light gray.
# ncal -b -3 -h lays each month out in 20 columns with a 2-column gap.
title="#[fg=cyan]$(printf '\356\202\266')#[bg=cyan,fg=black,bold]Calendar#[bg=default,fg=cyan,nobold]$(printf '\356\202\264')"

# $1: tmux (styles for menu item names, #[nodim] undoing disabled-item dimming)
# or ansi (escapes for the popup)
rows() {
    if [ "$1" = tmux ]; then
        set -- '#[nodim]' '#[fg=brightwhite]' '#[fg=colour248]' '#[fg=white]' \
            '#[reverse,fg=cyan]' '#[noreverse,fg=white]' ''
    else
        set -- '' '\033[97m' '\033[38;5;248m' '\033[37m' \
            '\033[7;36m' '\033[27;37m' '\033[39m'
    fi
    ncal -b -3 -h | awk -v day="$(date +%-d)" -v pre="$1" -v wkd="$2" \
        -v gray="$3" -v white="$4" -v on="$5" -v off="$6" -v end="$7" '
    NR == 1 { print pre $0; next }
    NR == 2 { print pre wkd $0 end; next }
    {
        cur = substr($0, 23, 20)
        for (i = 1; i <= 19; i += 3)
            if (substr(cur, i, 2) == sprintf("%2d", day)) {
                cur = substr(cur, 1, i - 1) on substr(cur, i, 2) off substr(cur, i + 2)
                break
            }
        print pre gray substr($0, 1, 20) "  " white cur "  " gray substr($0, 45) end
    }'
}

case $1 in
key)
    exec tmux display-popup -E -x '#{e|-:#{client_width},#{popup_width}}' -y S \
        -w 68 -h 10 -s fg=cyan -S fg=cyan -b rounded -T "$title" "$0 draw"
    ;;
draw)
    # No trailing newline: it would scroll the first row out of the popup.
    printf '\033[?25l%s' "$(rows ansi)"
    stty -echo -icanon min 1
    dd bs=1 count=1 >/dev/null 2>&1
    exit
    ;;
esac

set --
while IFS= read -r row; do
    set -- "$@" "-$row" "" ""
done <<EOF
$(rows tmux)
EOF
tmux display-menu -M -O -x '#{e|-:#{client_width},#{popup_width}}' -y S \
    -s fg=cyan -S fg=cyan -b rounded -T "$title" -- "$@"
