---
name: pr-tracker
description: Track Vivek's own open PRs in a DavisMechatronics repo through to merge. Keeps a status-line todo list with one item per PR (done = approved), runs a monitor that reports review, CI and draft changes, sends an lmk alert on approval, spawns merge-check Claudes, and cleans up after merges. Use when Vivek says "start a monitor on my PRs", "track my <repo> PRs", "make a todo list of my PRs", "lmk when any gets approved", "spawn a claude to do a merge check on N", or "N is merged".
---

# PR tracker

This session becomes the tracker for Vivek's authored PRs in one repo. It is built from other skills:
- **statusline-todo** (`mcp__statusline-todo__todo`) holds the list.
- **lmk** sends the alerts.
- **spawn-claude** and **relay** (`agents.py`) run and find the merge-check agents.
- **review-loop** is often run by other agents on the same PRs.

It works in any DavisMechatronics repo. Run commands from the repo's canon checkout, e.g. `~/DavisMechatronics/robocore`.

## 0. Name the window

First thing, rename this session's tmux window so Vivek can find the tracker:

```bash
tmux rename-window -t "$TMUX_PANE" pr-tracker
```

`-t "$TMUX_PANE"` targets the window this pane is in, not whichever window is active. Skip this if `$TMUX_PANE` is empty, because then the session isn't in tmux.

## 1. Seed the todo list

```bash
gh pr list --author @me --state open --json number,title,url,isDraft,reviewDecision,statusCheckRollup,reviewRequests,latestReviews
```

Add one todo item per PR:

`[󰇧 #N short title](<url>) (<reviewers>; <CI>)`

- **Reviewers:** use first names, mapping logins through the coworker list in the global CLAUDE.md. Mark each name's state where it helps, e.g. `James ✔`, `Evan changes`, `bot`.
- **CI:** one word, `green`, `running` or `FAILED`. Don't give per-check counts; Vivek finds them noisy.
- **Done:** an item is done when `reviewDecision == APPROVED`. Mark it with the tool's `done`.
- **Rendering:** the status line renders `[text](url)` as a clickable link. Keep `[` out of the link text.
- **Updating an item:** text can't be edited in place. Remove the item and add it again, then check its index with `list`, because indices shift.

Show Vivek a short status table:

| PR | Reviewers | CI | State |
| --- | --- | --- | --- |

Use links that follow the global CLAUDE.md glyph rules.

## 2. Monitor

Run [pr_watch.sh](pr_watch.sh) under the Monitor tool:

```bash
~/.claude/skills/pr-tracker/pr_watch.sh <repo-dir or owner/name> [interval, default 60]
```

It polls `gh` and prints only what changed:
- `NEW #N`, `CHANGED #N` (`old -> new`) or `GONE #N` (merged or closed).
- What it compares: draft, reviewDecision, each reviewer's latest review, pending review requests, and CI collapsed to running/green/FAILED.

**Re-arming:** the Monitor tool stops after 30 minutes, so re-arm it every time it expires without being asked. After a long silence, run the `gh pr list` above by hand once to confirm the watcher isn't blind, e.g. from an auth or query failure.

**Muting:** the mute file is printed on the first line, at `~/.cache/pr-tracker/<owner>_<name>.mute`. It holds one PR number per line. Muted PRs produce no events, and the file is re-read on every poll.

On each event:

| Event | Do |
| --- | --- |
| reviewDecision becomes APPROVED | Mark the item done, update its text, then send an lmk alert in after-mode ("#N approved by <Name>"). |
| CHANGES_REQUESTED, a new human reviewer, or CI turns FAILED | Tell Vivek in one line and update the item. CI FAILED is worth an lmk alert. |
| CI running→green, or a re-request with no new information | Update the item quietly. Mention it only if Vivek is waiting on it. |
| NEW | Add an item. |
| GONE | Verify with `gh pr view N --json state,mergedAt,mergeCommit`. If MERGED, go to section 4. If CLOSED, ask before removing the item. |

**PRs that another agent is working on** (e.g. a review-loop agent running dm-review-bot rounds): report only review results, new human reviewers, CI failures and approvals. Don't report every tick.

## 3. Merge check

On "spawn a claude to do a merge check on N":

1. Confirm that N is open and approved.
2. Find its branch: `gh pr view N --json headRefName,title,url`.
3. Check for an existing worktree with `git worktree list`.
4. Find your own peer name and pane: the `(you)` row of `~/.claude/skills/relay/agents.py`.
5. Spawn the agent:
   ```bash
   ~/.claude/skills/spawn-claude/spawn-claude.sh -d <worktree or canon dir> -n pr<N>-merge -- "<prompt>"
   ```
   The prompt is the merge-check template in [prompts.md](prompts.md), filled in.
6. **Hand over ownership.** Add N to the mute file straight away. Until that agent's final **done** note arrives, say nothing about N: no events and no lmk alerts. Vivek is talking to that agent directly, so anything from the tracker is duplicate noise.

   Its "ready to merge" message is **not** the handback. Acknowledge it silently.
7. When the done note arrives:
   - Remove N from the mute file.
   - Verify on GitHub.
   - Continue with section 4 if it merged; otherwise update the item.

prompts.md also holds a review template, for spawning a Claude to review a coworker's PR when Vivek's review is requested. It uses the same done-note and close-out rules.

## 4. After a merge

Do this when the done note says merged, or when Vivek says N merged.

1. Verify it with `gh pr view N --json state,mergeCommit`. Never merge anything yourself. Merging, and anything else that changes main, is Vivek's to do or to approve at that moment, per the global CLAUDE.md.
2. Remove the todo item.
3. Bring the canon checkout up to date: `git -C <canon> pull --ff-only`, if it is on main and clean. If it isn't, say so and leave it.
4. Clean up the PR's worktree and local branch if nothing else uses them. If a spawned agent's pane still has the worktree open, check with `agents.py` first.
5. Report it in one line, with the merge commit.

## Spawned agents always report before closing

Every spawn prompt with a close-out step must keep this order:

1. Clean up.
2. Send the tracker a done note by SendMessage. It says the PR state (merged or not) and what was cleaned up or left.
3. Only then, `tmux kill-window` its own window.

Before this rule, agents closed silently and the tracker found out late or not at all.
