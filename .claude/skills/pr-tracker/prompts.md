# Spawn prompts for pr-tracker

Fill in the `<…>` parts:
- `<repo>`: the repo name.
- `<N>`, `<title>`, `<branch>`: from `gh pr view`.
- `<tracker>`, `<peer>`, `<pane>`: from the `(you)` row of `~/.claude/skills/relay/agents.py`.
  - `<tracker>` is the task label, e.g. `pr-status`.
  - `<peer>` is the peer name, e.g. `robocore-d3`.
  - `<pane>` looks like `robocore:1.1`.
- `<test tools>`: the repo's affected-test scripts.
  - robocore: `scripts/affected_tests.py` and `scripts/changed_code.py`.
  - vendees: `core/scripts/…`.
  - if the repo has neither, say "the tests covering the changed code".

Check the PR is still open before spawning.

## Merge check (Vivek's own approved PR)

> Merge check for <repo> PR #<N> (<title>, branch <branch>). It is approved, and I want to merge it
> soon. First, briefly explain its purpose, strategy and implementation so I can re-familiarize.
> Then check whether it is behind main, and whether it has textual or semantic conflicts with what
> has landed on main since it branched. If it needs a rebase, rebase the feature branch onto main
> and push with --force-with-lease. That is the only push allowed: never push or merge main, and
> take no other GitHub action (no merge, comment, review or label) unless I ask. Run the affected
> tests (<test tools>), then the full suite, and report results against the known baseline.
> When the checks are finished, send a one-line "ready to merge" (or "blocked: why") note via
> SendMessage to the <tracker> agent, peer <peer> (tmux <pane>), and tell me the same in chat.
> When I say I'm done: (1) remove your worktree and its local branch, unless it was an existing
> worktree you were told to leave; (2) send a short "done" note to <peer>: merged or not, merge
> commit, whether you rebased, test results, what you cleaned up or left; (3) only then close your
> own tmux window with: tmux kill-window -t "$(tmux display -p -t "$TMUX_PANE" '#S:#I')". Do not
> close it before I say I'm done.

If the branch is already checked out in an existing worktree, point `-d` at it, and add "This
worktree already existed: leave it; the tracker removes it after merge."

## Review (a coworker's PR where Vivek's review is requested; review tracker)

Spawn with `-d <canon dir> -n pr<N>-review`. Fill `<Name>/<login>` from the coworker list.

> Review <repo> PR #<N> (<title>, by <Name>/<login>, branch <branch>). My review is requested.
> Assume I have not followed this work and know nothing about the PR beyond its title. You are my
> point of contact for this review: delegate the review work to background subagents and keep
> yourself free to talk with me while it runs.
> Step 1: check it out in a worktree tracking the PR branch: git fetch origin <branch> && git
> worktree add --track -b pr<N>-review .claude/worktrees/pr<N>-review origin/<branch>, then cd into
> it.
> Step 2: launch two background subagents in parallel, then go straight to step 3 without waiting
> on them: (a) the repo's reviewer agent per my global CLAUDE.md (code-change-reviewer by default),
> passing it the PR description as the original request; (b) a general-purpose agent that runs the
> affected tests (<test tools>) in the worktree and reports pass/fail counts and any failure.<checks>
> Step 3: read the PR description and diff yourself and send me a BRIEFING, under 200 words. This
> is your first chat text after the worktree exists; write nothing else before it. Exactly this
> shape: "TL;DR:" one plain sentence on what the PR does. "Why:" 2-3 bullets on the problem it
> solves and who feels it. "How:" 3-5 bullets, one per architectural decision (not per file), each
> naming the trade-off it makes, e.g. "reuses X's format instead of a new schema, so no new reader,
> but the two can drift". "Shape:" one line on where the diff's weight sits. Define any
> project-specific term, component or host name on first use. No verdict, findings, risks,
> file-by-file walkthrough, test results or line numbers in the briefing. Then end your turn: the
> subagents finishing wakes you. If I ask questions meanwhile, answer them yourself.
> Step 4: when both subagents have returned, verify the reviewer's findings against the code
> (delegate the verification if it is large) and drop any you can't confirm. Then send me the
> REVIEW, under 250 words, in exactly this shape and nothing else: one line with the verdict
> (approve or request changes) and why; at most 5 findings that the PR introduces, ranked, each
> 1-2 lines with file:line and your view (blocker or should fix); all nits together on one line;
> problems that predate the PR on one line, only if they matter for this review; one line of test
> results. No sections for checks that came back clean or for what you didn't review. Offer to
> expand any point or walk through the implementation; don't do it unasked.
> Do not post, approve, request changes or comment on GitHub unless I ask; if I ask, draft the text
> for me to confirm first, as a blockquote. When I say I'm done: (1) remove your review worktree
> and its local branch; (2) send a short summary via SendMessage to the <tracker> agent, peer
> <peer> (tmux <pane>): verdict, top findings, what I did on GitHub, the head commit reviewed,
> whether the PR merged or changed meanwhile; (3) only then close your own tmux window with: tmux
> kill-window -t "$(tmux display -p -t "$TMUX_PANE" '#S:#I')". Do not close it before I say I'm done.

`<checks>` is where PR-specific concerns go, as at most 3 short questions about what the PR
changes, appended to subagent (b)'s task, e.g. " Also answer, from the code: what credentials the
upload uses; what happens when S3 is unreachable." Leave it empty if there are none. Never put
checks in the briefing, and never feed in Vivek's side work (spikes, unsent notes, memory files):
a check's answer reaches the review only as a finding, when it turns up a problem the PR
introduces.

For a re-review (author pushed or re-requested after an earlier round), add: "This is a re-review;
I last reviewed at <sha>. Base the briefing and the review on what changed since then
(`git diff <sha>..HEAD`, or the range-diff if the branch was rebased): the briefing's TL;DR says
what changed and Why says which of my earlier comments it answers; the review says, per earlier
comment, addressed or not, then any new findings."
