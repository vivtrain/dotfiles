#!/usr/bin/env bash
# Claude Code status line: model + cwd + current branch's PR.
# Vim mode badge and cursor shape are drawn by the vim-badge plugin instead.
# The built-in PR footer is off (prStatusFooterEnabled=false in ~/.claude.json).

input=$(cat)
IFS=$'\x1f' read -r model dir sid < <(jq -r '[.model.display_name // "", .workspace.current_dir // .cwd // "", .session_id // ""] | join("\u001f")' <<<"$input")

# Model in bold black on a rounded Anthropic orange (#D97757) bubble.
line=
[ -n "$model" ] && line+=$(printf '\e[38;2;217;119;87m\ue0b6\e[48;2;217;119;87;38;2;0;0;0;1m\U000f06a9 %s\e[22;49;38;2;217;119;87m\ue0b4\e[0m' "$model")
[ -n "$dir" ] && line+=$(printf ' \e[34m%s\e[0m' "${dir/#$HOME/\~}")
printf '%s' "$line"

# Session pins (~/.local/bin/pin): red pin, white count, right-aligned on the first line; shown
# once there is at least one. Claude Code passes the width as $COLUMNS but draws the line
# narrower (it ellipsizes at COLUMNS-2), so pin_margin columns stay spare; raise it if it cuts off.
pin_margin=6
pins=$([ -n "$sid" ] && grep -c . "$HOME/.cache/claude-pins/$sid.tsv" 2>/dev/null)
if [ "${pins:-0}" -gt 0 ]; then
  plain=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$line")
  pad=$(( ${COLUMNS:-80} - pin_margin - $(LC_ALL=C.UTF-8 bash -c 'echo ${#1}' _ "$plain") - 2 - ${#pins} ))
  printf '%*s\e[31m\U000f0403\e[97m %s\e[0m' "$(( pad > 1 ? pad : 1 ))" '' "$pins"
fi

# PR for the current branch, on its own line, as an OSC 8 hyperlink: the PR state icon and bold
# number in a pill colored by review status, then the title in muted lavender (256-color 146).
# Review colors: white none requested, yellow awaiting review, green approved, red changes requested.
# This runs every second, so gh is only called in the background, at most once a minute per branch.
pr_ttl=60
branch=$([ -n "$dir" ] && git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline
  cache=$cache_dir/pr-$(printf '%s\n%s' "$top" "$branch" | md5sum | cut -c1-16)
  if [ ! -e "$cache" ] || [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -ge $pr_ttl ]; then
    mkdir -p "$cache_dir"
    touch "$cache"  # doubles as a lock so the next ticks don't spawn another gh
    ( cd "$top" && gh pr view "$branch" --json number,title,url,state,isDraft,reviewDecision,reviewRequests,latestReviews \
        -q '(.latestReviews | map(.state)) as $r
            | (if (.reviewRequests | length) > 0 then "pending"
               elif .reviewDecision == "CHANGES_REQUESTED" or ($r | index("CHANGES_REQUESTED")) then "changes"
               elif .reviewDecision == "APPROVED" or ($r | index("APPROVED")) then "approved"
               else "none" end) as $review
            | (if .isDraft then "DRAFT" else .state end) as $state
            | [.number, .title, .url, $state, $review] | map(tostring) | join("\u001f")' >"$cache.tmp" 2>/dev/null \
        || : >"$cache.tmp"; mv "$cache.tmp" "$cache" ) </dev/null >/dev/null 2>&1 &
    disown
  fi
  IFS=$'\x1f' read -r num title url state review <"$cache"
  if [ -n "$num" ]; then
    case $state in  # octicons, plus fa-code_merge for merged
      DRAFT)  icon=$'\uf4dd' ;;
      CLOSED) icon=$'\uf4dc' ;;
      MERGED) icon=$'\uf17f' ;;
      *)      icon=$'\uf407' ;;
    esac
    case $review in  # truecolor (kitty theme's hexes) so caps and body resolve to the same shade
      pending)  rgb='249;226;175' ;;
      approved) rgb='166;227;161' ;;
      changes)  rgb='243;139;168' ;;
      *)        rgb='255;255;255' ;;
    esac
    printf '\n\e]8;;%s\e\\\e[38;2;%sm\ue0b6\e[48;2;%s;38;2;0;0;0;1m%s %s\e[22;49;38;2;%sm\ue0b4\e[38;5;146m %s\e[0m\e]8;;\e\\' \
      "$url" "$rgb" "$rgb" "$icon" "$num" "$rgb" "$title"
  fi
fi
exit 0
