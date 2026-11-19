#!/usr/bin/env bash
# Watch my open PRs in one GitHub repo and print one line per change, for the Monitor tool.
# Usage: pr_watch.sh <repo-dir | owner/name> [interval-seconds, default 60]
# Lines: NEW #N title: state / CHANGED #N title: old -> new / GONE #N: MERGED|CLOSED decision=...
# State per PR: draft, reviewDecision, CI collapsed to running|green|FAILED, each reviewer's latest
# review, pending review requests. Quiet when nothing changed.
# Mute file: $XDG_CACHE_HOME/pr-tracker/<owner>_<name>.mute, one PR number per line (e.g. 245).
# Muted PRs emit nothing; it is re-read every poll, so edit it while the watcher runs.
set -u
src=${1:?usage: pr_watch.sh <repo-dir|owner/name> [interval]}
interval=${2:-60}
if [ -d "$src" ]; then
  repo=$(cd "$src" && gh repo view --json nameWithOwner --jq .nameWithOwner) || exit 1
else
  repo=$src
fi
MUTE=${XDG_CACHE_HOME:-$HOME/.cache}/pr-tracker/${repo/\//_}.mute
mkdir -p "$(dirname "$MUTE")"
muted() { [ -f "$MUTE" ] && grep -qx "${1#\#}" "$MUTE"; }
snap() {
  gh pr list -R "$repo" --author @me --state open \
    --json number,title,isDraft,reviewDecision,statusCheckRollup,reviewRequests,latestReviews \
    --jq '.[] | "#\(.number)\t\(.title[0:50])\tdraft=\(.isDraft) decision=\(.reviewDecision) ci=\([.statusCheckRollup[]?|(.conclusion // .state // "")] as $c | if any($c[]; test("FAIL|ERROR|CANCEL|TIMED_OUT|ACTION_REQUIRED")) then "FAILED" elif any($c[]; . == "" or test("PENDING|IN_PROGRESS|QUEUED|EXPECTED")) then "running" else "green" end) reviews=\([.latestReviews[]|"\(.author.login):\(.state)"]|sort|join(",")) requested=\([.reviewRequests[].login]|sort|join(","))"' \
    2>/dev/null | sort
}
echo "watching $repo every ${interval}s; mute file $MUTE"
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
