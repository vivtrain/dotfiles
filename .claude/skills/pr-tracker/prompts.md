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
> Check it out in a worktree tracking the PR branch: git fetch origin <branch> && git worktree add
> --track -b pr<N>-review .claude/worktrees/pr<N>-review origin/<branch>. As soon as the worktree exists,
> launch the repo's reviewer agent per my global CLAUDE.md (code-change-reviewer by default) in the
> background, passing it the PR description as the original request, so it runs while I read.
> While it runs, write me a high-level explanation of the PR to read: the problem it solves and why,
> the strategy and the alternatives it implies, a walkthrough of the implementation file by file in
> reading order, anything surprising or risky, and what I should look at most closely. Keep it to
> what I need to review well, not a restatement of the diff. Then run the affected tests
> (<test tools>). When the reviewer agent returns, verify its findings against the code yourself
> and report them in chat, ranked, with your own view on each; drop any you can't confirm. Do not
> post, approve, request changes or comment on GitHub unless I ask; if I ask, draft the text for me
> to confirm first. When I say I'm done: (1) remove your review worktree and its local branch;
> (2) send a short summary via SendMessage to the <tracker> agent, peer <peer> (tmux <pane>):
> verdict, top findings, what I did on GitHub, the head commit reviewed, whether the PR merged or
> changed meanwhile; (3) only then close your own tmux window with: tmux kill-window -t
> "$(tmux display -p -t "$TMUX_PANE" '#S:#I')". Do not close it before I say I'm done.

For a re-review (author pushed or re-requested after an earlier round), add: "This is a re-review;
I last reviewed at <sha>. Focus the explanation and the review on what changed since then
(`git diff <sha>..HEAD`, or the range-diff if the branch was rebased), and on whether my earlier
comments were addressed."
