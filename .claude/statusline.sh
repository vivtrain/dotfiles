#!/usr/bin/env bash
# Claude Code status line: model + cwd.
# Vim mode badge and cursor shape are drawn by the vim-badge plugin instead.

input=$(cat)
IFS=$'\x1f' read -r model dir < <(jq -r '[.model.display_name // "", .workspace.current_dir // .cwd // ""] | join("\u001f")' <<<"$input")
dir=${dir/#$HOME/\~}

[ -n "$model" ] && printf '\e[38;2;217;119;87m\U000f06a9 %s\e[0m' "$model"  # Anthropic orange #D97757
[ -n "$dir" ] && printf ' \e[36m%s\e[0m' "$dir"
exit 0
