---
name: pr-tracker
description: Track PRs in a DavisMechatronics repo in one of two modes. PR tracker follows Vivek's own open PRs through to merge and spawns merge-check Claudes. Review tracker follows coworkers' PRs where Vivek's review is requested and spawns review Claudes that explain the PR while the reviewer agent runs. Both keep a status-line todo list with one item per PR, run a monitor that reports review, CI, push and draft changes, send lmk alerts, and clean up after spawned agents. Use when Vivek says "start a monitor on my PRs", "track my <repo> PRs", "make a todo list of my PRs", "lmk when any gets approved", "spawn a claude to do a merge check on N", "N is merged", "start a review tracker", "track my review requests", "what's waiting on my review", or "spawn a claude to review N".
---

# PR tracker / review tracker

This session becomes the tracker for one repo, in one of two modes:

| | PR tracker | Review tracker |
| --- | --- | --- |
| Tracks | PRs Vivek authored | coworkers' PRs where Vivek's review is requested, or he has reviewed |
| Window name | `pr-tracker` | `review-tracker` |
| ✔ done when | `reviewDecision == APPROVED` | Vivek approved or commented on the current head and isn't re-requested |
| ✘ `fail` when | changes requested (decision or any human review) | Vivek's latest review requested changes |
| `~` `wip` when | a merge-check agent owns it | a review agent owns it |
| Spawns | merge checks (`pr<N>-merge`) | reviews (`pr<N>-review`) |
| Item removed when | merged (section 4a) | merged or closed (section 4b) |
| Watcher | `pr_watch.sh <repo>` | `pr_watch.sh --reviews <repo>` |

Pick the mode from what Vivek asks; ask only if it's genuinely unclear. One session runs one mode, since the todo list is per session. Spawning and closing are manual in both: spawn only when Vivek asks, and close out only on a done note or his word.

It is built from other skills:
- **statusline-todo** (`mcp__statusline-todo__todo`) holds the list.
- **lmk** sends the alerts.
- **spawn-claude** and **relay** (`agents.py`) run and find the spawned agents.
- **review-loop** is often run by other agents on Vivek's own PRs.

It works in any DavisMechatronics repo. Run commands from the repo's canon checkout, e.g. `~/DavisMechatronics/robocore`.

## 0. Name the window

First thing, rename this session's tmux window to the mode's name so Vivek can find the tracker:

```bash
tmux rename-window -t "$TMUX_PANE" pr-tracker      # or review-tracker
```

`-t "$TMUX_PANE"` targets the window this pane is in, not whichever window is active. Skip this if `$TMUX_PANE` is empty, because then the session isn't in tmux.

## 1. Seed the todo list

PR tracker:

```bash
gh pr list --author @me --state open --json number,title,url,isDraft,reviewDecision,statusCheckRollup,reviewRequests,latestReviews
```

Review tracker: a submitted review drops the request, so take the union of both searches and dedupe by number:

```bash
F=number,title,url,author,isDraft,reviewDecision,statusCheckRollup,reviewRequests,latestReviews,headRefOid
gh pr list --state open --search "review-requested:@me -author:@me" --json $F
gh pr list --state open --search "reviewed-by:@me -author:@me" --json $F
```

Add one todo item per PR:

- PR tracker: `[󰇧 #N short title](<url>) (<reviewers>; <CI>)`
- Review tracker: `[󰇧 #N short title](<url>) (<Author>; <my state>; <CI>)`, where my state is `to review`, `re-review` (re-requested, or author pushed since my review), `reviewed ✔`, `changes req'd` or `commented`. Add `draft` if it is one.

Rules for both:
- **Names:** use first names, mapping logins through the coworker list in the global CLAUDE.md. In PR tracker, mark each reviewer's state where it helps, e.g. `James ✔`, `Evan changes`, `bot`.
- **CI:** one word, `green`, `running` or `FAILED`. Don't give per-check counts; Vivek finds them noisy.
- **State marker:** each item carries one of the todo list's four states, per the mode table:
  - `~` (`wip`) while a spawned agent owns the PR. This wins over everything else until its done note arrives.
  - Otherwise ✘ (`fail`) when changes are requested, ✔ (`done`) when it's done, else ☐ open (`undo`).
  - In review tracker an item goes back to ☐ when Vivek is re-requested or the author pushes after his review.
  - Set states with the todo tool's `done`, `fail`, `wip` and `undo` actions. If the tool rejects `fail` or `wip` (this session started before they existed), use the CLI, which finds this session from the tmux pane: `todo fail N`, `todo wip N`, `todo done N`, `todo undo N`.
  - Re-adding an item to update its text resets it to ☐, so set its state again right after.
- **Rendering:** the status line renders `[text](url)` as a clickable link. Keep `[` out of the link text.
- **Updating an item:** text can't be edited in place. Remove the item and add it again, then check its index with `list`, because indices shift.

Show Vivek a short status table, using links that follow the global CLAUDE.md glyph rules:

| PR | Reviewers | CI | State |
| --- | --- | --- | --- |

In review tracker the columns are PR, Author, My state, CI, Others (other reviewers' states), oldest request first.

## 2. Monitor

Run [pr_watch.sh](pr_watch.sh) under the Monitor tool:

```bash
~/.claude/skills/pr-tracker/pr_watch.sh [--reviews] <repo-dir or owner/name> [interval, default 60]
```

It polls `gh` and prints only what changed:
- `NEW #N`, `CHANGED #N` (`old -> new`) or `GONE #N` (merged or closed, or in review mode also no longer involving Vivek).
- What it compares: draft, reviewDecision, each reviewer's latest review, pending review requests, and CI collapsed to running/green/FAILED. `--reviews` also compares `head=<sha7>` (author pushed) and `me=requested|<my latest review state>|none`, and puts the author's login after the title.

**Re-arming:** the Monitor tool stops after 30 minutes, so re-arm it every time it expires without being asked. After a long silence, run the section 1 query by hand once to confirm the watcher isn't blind, e.g. from an auth or query failure.

**Muting:** the mute file is printed on the first line: `~/.cache/pr-tracker/<owner>_<name>.mute`, or `<owner>_<name>.reviews.mute` in review mode, so the two trackers never mute each other. It holds one PR number per line. Muted PRs produce no events, and the file is re-read on every poll.

### PR tracker events

| Event | Do |
| --- | --- |
| reviewDecision becomes APPROVED | Mark the item done, update its text, then send an lmk alert in after-mode ("#N approved by <Name>"). |
| CHANGES_REQUESTED (decision or a human reviewer's latest review) | Mark the item ✘ `fail`, tell Vivek in one line, lmk alert. Back to ☐ once that reviewer re-reviews without requesting changes. |
| A new human reviewer, or CI turns FAILED | Tell Vivek in one line and update the item. CI FAILED is worth an lmk alert. |
| CI running→green, or a re-request with no new information | Update the item quietly. Mention it only if Vivek is waiting on it. |
| NEW | Add an item. |
| GONE | Verify with `gh pr view N --json state,mergedAt,mergeCommit`. If MERGED, go to section 4a. If CLOSED, ask before removing the item. |

**PRs that another agent is working on** (e.g. a review-loop agent running dm-review-bot rounds): report only review results, new human reviewers, CI failures and approvals. Don't report every tick.

### Review tracker events

| Event | Do |
| --- | --- |
| NEW with `me=requested` | Add an item, then lmk alert in after-mode ("<Author> requested your review on #N"). |
| `me` becomes `requested` again (re-request), or `head` changes after Vivek reviewed | Set the item back to ☐ (`undo`), label it `re-review`, tell Vivek in one line, lmk alert. |
| `me` goes from `requested` to a review state (Vivek reviewed, e.g. on the web) | ✘ `fail` if CHANGES_REQUESTED, else ✔ `done`. Update the item quietly. |
| draft→ready | Tell Vivek in one line; it is now worth reviewing. |
| `head` changes before Vivek reviewed, other reviewers' reviews, decision changes, CI | Update the item quietly. Mention it only if it changes what Vivek should do, e.g. someone else already approved or requested changes, or CI FAILED. |
| GONE | Check with `gh pr view N --json state,mergedAt,reviewRequests`. MERGED or CLOSED: section 4b. Still open but no longer involving Vivek (request withdrawn before he reviewed): tell him, ask before removing. |

## 3. Spawning (on request only)

On "spawn a claude to do a merge check on N" (PR tracker) or "spawn a claude to review N" (review tracker):

1. Confirm that N is open. For a merge check, also confirm it is approved. For a review, note whether it is a re-review and the head Vivek last reviewed (his latest review's commit: `gh api repos/<owner>/<name>/pulls/N/reviews --jq '[.[]|select(.user.login=="vivtrain")]|last|.commit_id'`).
2. Find its branch: `gh pr view N --json headRefName,title,url,author`.
3. Check for an existing worktree with `git worktree list`.
4. Find your own peer name and pane: the `(you)` row of `~/.claude/skills/relay/agents.py`.
5. Spawn the agent:
   ```bash
   ~/.claude/skills/spawn-claude/spawn-claude.sh -d <worktree or canon dir> -n pr<N>-merge -- "<prompt>"   # or -n pr<N>-review
   ```
   The prompt is the merge-check or review template in [prompts.md](prompts.md), filled in. Tell Vivek in one line, linking the new pane per the global CLAUDE.md agent rules.
6. **Hand over ownership.** Mark N's item `~` (`wip`) and add N to the mode's mute file straight away. Until that agent's final **done** note arrives, say nothing about N: no events and no lmk alerts. Vivek is talking to that agent directly, so anything from the tracker is duplicate noise.

   Interim messages ("ready to merge", "review posted") are **not** the handback. Acknowledge them silently.
7. When the done note arrives:
   - Remove N from the mute file, and replace the `~` with the state GitHub now shows.
   - Verify on GitHub.
   - Continue with section 4a or 4b, or just update the item.

## 4a. After a merge (PR tracker)

Do this when the done note says merged, or when Vivek says N merged.

1. Verify it with `gh pr view N --json state,mergeCommit`. Never merge anything yourself. Merging, and anything else that changes main, is Vivek's to do or to approve at that moment, per the global CLAUDE.md.
2. Remove the todo item.
3. Bring the canon checkout up to date: `git -C <canon> pull --ff-only`, if it is on main and clean. If it isn't, say so and leave it.
4. Clean up the PR's worktree and local branch if nothing else uses them. If a spawned agent's pane still has the worktree open, check with `agents.py` first.
5. Report it in one line, with the merge commit.

## 4b. After a review (review tracker)

When a review agent's done note arrives:

1. Verify with `gh pr view N --json state,reviewDecision,latestReviews,reviewRequests,headRefOid`. Never post, approve or comment yourself; that is Vivek's, through the review agent.
2. If the PR is still open, keep the item and replace its `~`: ✘ if Vivek requested changes, ✔ if he approved or commented on the current head, otherwise ☐ with what's left (e.g. `review not posted`). The watcher will re-raise it on a re-request or a push.
3. If it is merged or closed, remove the item, and pull the canon checkout as in 4a step 3 if it merged.
4. Make sure the `pr<N>-review` worktree and branch are gone; remove leftovers if nothing uses them.
5. Report it in one line: verdict and what Vivek did on GitHub, from the note.

Items for PRs that merge or close without a spawned review just get removed, with a one-line mention.

## Spawned agents always report before closing

Every spawn prompt with a close-out step must keep this order:

1. Clean up.
2. Send the tracker a done note by SendMessage. It says the PR state (merged or not) and what was cleaned up or left.
3. Only then, `tmux kill-window` its own window.

Before this rule, agents closed silently and the tracker found out late or not at all.
