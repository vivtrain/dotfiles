#!/usr/bin/env bash
# Watch open PRs in one GitHub repo and print one line per change, for the Monitor tool.
# Usage: pr_watch.sh [--reviews] <repo-dir | owner/name> [interval-seconds, default 60]
#   default    PR tracker: PRs I authored.
#   --reviews  review tracker: others' PRs where my review is requested or I have reviewed.
# Lines: NEW #N title: state / CHANGED #N title: old -> new / GONE #N: MERGED|CLOSED decision=...
# State per PR: draft, reviewDecision, CI collapsed to running|green|FAILED, each reviewer's latest
# review, pending review requests. --reviews adds head=<sha7> (author pushed) and
# me=requested|<my latest review state>|none.
# Mute file: $XDG_CACHE_HOME/pr-tracker/<owner>_<name>[.reviews].mute, one PR number per line.
# Muted PRs emit nothing; it is re-read every poll, so edit it while the watcher runs.
set -u
mode=prs
[ "${1:-}" = --reviews ] && { mode=reviews; shift; }
src=${1:?usage: pr_watch.sh [--reviews] <repo-dir|owner/name> [interval]}
interval=${2:-60}
if [ -d "$src" ]; then
  repo=$(cd "$src" && gh repo view --json nameWithOwner --jq .nameWithOwner) || exit 1
else
  repo=$src
fi
suffix=; [ "$mode" = reviews ] && suffix=.reviews
MUTE=${XDG_CACHE_HOME:-$HOME/.cache}/pr-tracker/${repo/\//_}$suffix.mute
mkdir -p "$(dirname "$MUTE")"
muted() { [ -f "$MUTE" ] && grep -qx "${1#\#}" "$MUTE"; }
me=$(gh api user --jq .login) || exit 1

FIELDS=number,title,author,isDraft,reviewDecision,statusCheckRollup,reviewRequests,latestReviews,headRefOid
JQ='
def ci: [.statusCheckRollup[]?|(.conclusion // .state // "")] as $c
  | if any($c[]; test("FAIL|ERROR|CANCEL|TIMED_OUT|ACTION_REQUIRED")) then "FAILED"
    elif any($c[]; . == "" or test("PENDING|IN_PROGRESS|QUEUED|EXPECTED")) then "running"
    else "green" end;
def reqs: [.reviewRequests[]|(.login // .slug // .name)];
.[] | "#\(.number)\t\(.title[0:50])\(if $mode == "reviews" then " (\(.author.login))" else "" end)\tdraft=\(.isDraft) decision=\(.reviewDecision) ci=\(ci)"
  + (if $mode == "reviews" then
       " head=\(.headRefOid[0:7]) me=\(if (reqs|index($me)) then "requested"
         else ([.latestReviews[]|select(.author.login == $me)|.state][0] // "none") end)"
     else "" end)
  + " reviews=\([.latestReviews[]|"\(.author.login):\(.state)"]|sort|join(",")) requested=\(reqs|sort|join(","))"'
list() { gh pr list -R "$repo" --state open --limit 100 --json "$FIELDS" "$@"; }
snap() {
  local raw
  if [ "$mode" = reviews ]; then
    # A submitted review drops the request, so union "requested" with "reviewed by me".
    raw=$( { list --search "review-requested:@me -author:@me" && \
             list --search "reviewed-by:@me -author:@me"; } 2>/dev/null | jq -s 'add | unique_by(.number)') || return 1
  else
    raw=$(list --author @me 2>/dev/null) || return 1
  fi
  jq -r --arg mode "$mode" --arg me "$me" "$JQ" <<<"$raw" | sort
}
echo "watching $repo ($mode) as $me every ${interval}s; mute file $MUTE"
prev=$(snap)
while true; do
  sleep "$interval"
  cur=$(snap) || continue
  [ -z "$cur" ] && [ -n "$prev" ] && continue   # transient API failure looks like "no PRs"
  comm -13 <(echo "$prev") <(echo "$cur") | while IFS=$'\t' read -r n t rest; do
    [ -n "$n" ] || continue
    muted "$n" && continue
    old=$(echo "$prev" | awk -F'\t' -v n="$n" '$1==n{print $3}')
    if [ -z "$old" ]; then echo "NEW $n $t: $rest"; else echo "CHANGED $n $t: $old  ->  $rest"; fi
  done
  for n in $(comm -23 <(echo "$prev" | cut -f1 | sort) <(echo "$cur" | cut -f1 | sort)); do
    muted "$n" && continue
    st=$(gh pr view "${n#\#}" -R "$repo" --json state,reviewDecision --jq '"\(.state) decision=\(.reviewDecision)"' 2>/dev/null)
    echo "GONE $n: ${st:-unknown}"
  done
  prev=$cur
done
