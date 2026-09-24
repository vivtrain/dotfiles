#!/usr/bin/env bash
# Claude Code status line: colored vim mode badge + model + cwd.
# Also sets the terminal cursor shape (DECSCUSR) to match the vim mode.

input=$(cat)
IFS=$'\x1f' read -r mode model dir < <(jq -r '[.vim.mode // "", .model.display_name // "", .workspace.current_dir // .cwd // ""] | join("\u001f")' <<<"$input")
dir=${dir/#$HOME/\~}

# Rounded powerline bubble: left cap U+E0B6, right cap U+E0B4 (needs a Nerd Font).
bubble() {  # $1 = color number (0-7), $2 = text
  printf '\e[3%sm\ue0b6\e[1;30;4%sm%s\e[0;3%sm\ue0b4\e[0m' "$1" "$1" "$2" "$1"
}

case "$mode" in
  NORMAL) badge=$(bubble 4 NORMAL); cursor=$'\e[2 q' ;;  # blue, steady block
  INSERT) badge=$(bubble 2 INSERT); cursor=$'\e[6 q' ;;  # green, steady bar
  VISUAL*) badge=$(bubble 5 "$mode"); cursor=$'\e[2 q' ;;  # magenta, block
  "") badge=""; cursor="" ;;
  *) badge=$(bubble 7 "$mode"); cursor="" ;;
esac

# Experimental: set cursor shape. The status line runs without a controlling tty,
# so walk up the process tree to find the terminal Claude Code is drawing on.
# Only fires when the status line re-renders, so it may lag the mode switch.
if [ -n "$cursor" ]; then
  pid=$PPID
  while [ "${pid:-1}" -gt 1 ]; do
    t=$(ps -o tty= -p "$pid" | tr -d ' ')
    [ -n "$t" ] && [ "$t" != "?" ] && { printf '%s' "$cursor" > "/dev/$t"; break; } 2>/dev/null
    pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
  done
fi

printf '%s' "$badge"
[ -n "$model" ] && printf ' \e[2m%s\e[0m' "$model"
[ -n "$dir" ] && printf ' \e[36m%s\e[0m' "$dir"
exit 0
