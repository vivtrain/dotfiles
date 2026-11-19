# Global notes

Applies to every project. Drop notes below as plain bullets.

## Company style guide (Davis Mechatronics)

Apply it by default to anything company-facing I ask you to make: PDFs, reports, HTML pages,
slides, plots and diagrams, UI mockups. Skip it only if I say otherwise.

- Source of truth: `~/Documents/davis-mech_brand-guidelines.pdf`. It has 3 pages: logo formats, logo rules, color.
- Logo and asset files, in `~/Pictures/`, all transparent-background PNGs unless noted:
  - `davis-mech_full-logo_on-light.png` (1139×366): standard logo for white or light backgrounds. Blue wordmark, beige circuit.
  - `davis-mech_full-logo_on-dark.png` (1139×366): reversed logo. White "DAVIS" and gear, so it is invisible on white.
    Place it only on Blue 1 `#163258` or another dark, plain background.
  - `davis-mech_icon_on-light.png` / `davis-mech_icon_on-dark.png` (374×366): gear-plus-circuit icon only.
    Use it only where the full logo doesn't fit or adds nothing, e.g. favicons and small corner marks.
  - `davis-mech_profile-pic_on-light.jpg` / `_on-dark.jpg` (484×484 JPEG, square avatar):
    for avatars and social images, not for documents.
- Logo rules:
  - Use only those four logo configurations: full or icon, each on light or dark.
  - Never recolor, stretch or squish the logo, and never place it on bright, gradient or busy backgrounds.
  - Minimum height is 60px on screen and 0.75in in print.
  - Clear space on every side is at least the height of the "M" in MECHATRONICS.
- Colors:
  - Primary blues, for titles, accents and backgrounds: Blue 1 `#163258` (rgb 22,50,88), Blue 2 `#395a87` (57,90,135).
  - Neutrals, for plain backgrounds, body text and secondary titles: Dark grey `#1f1f1b`, Warm grey `#65665c`,
    Beige `#a6a696`, Cream `#d1d1bd`.
  - Accent greens, used sparingly: Green 1 `#a0a538`, Green 2 `#d1d923`. Never use them for body text.
    Only small bits of text may be green, and only on a dark background.
  - Default palette for charts and plots: Blue 1, Blue 2, Warm grey, Beige, then Green 1 to highlight a single series.
  - The PDF also gives CMYK values for print work.
- Typography: the guide names no font. The guide itself is set in Inter, so use Inter, falling back to system sans,
  with headings in Blue 1 or Warm grey and body text in Dark grey.
- Past reports in `~/Documents/reports/` are examples of the house style.
  They were made with headless Chrome HTML→PDF or with pypdf.

## My command-line verbiage

I talk in my aliases. Your Bash tool is non-interactive, so these aren't loaded there; expand them.

- "git please" = `git push --force-with-lease` (git alias). Plain "please" = `sudo`. `git rmb <branch>...` = delete branches locally + on upstream (`~/.local/scripts/git-rmb.sh`). Other git aliases: `git sw`/`ch`/`cb`, `rbc`/`rbi`/`rba` (rebase continue/interactive/abort),
  `unstage`, `ours`/`theirs`.
- Shell git shorthands: gs status, gd diff, gds diff --staged, ga/gap add(-p), gc/gcm commit,
  gca/gcan amend, gcf fixup, gp push, gf fetch --prune, gt one-line graph, gg git-graph viewer,
  gr cd to repo root.
- make: mk = make, mkr = make && ./run, mkc = make clean.
- `ldvenv`/`unldvenv` = activate/deactivate venv (`venv` or `.venv`). `mkvenv` = `python -m venv venv`.
- `today` = `date +%Y%m%d` (my date format for filenames/logs).
- `dml <pattern>` = open newest matching log in `/opt/dm/logs` (on robots).
- `sfs <host>` = sshfs-mount a device's `/` at `~/orin/`.
- `clip` / `paste` = xclip clipboard in/out. `open` = xdg-open. `md` = markdown preview in retext.
- `alert` / `alertc` = desktop notification (alertc is critical, shows through DND).
- `cd <name>` works for shortcuts in `~/.local/shortcuts`: ahs, lander, orin, playground,
  robocore, robofab, telehandler (all under `~/DavisMechatronics/`).

## Tools available

- Installed: tree, fzf, rg, jq, gh, uv, git-graph, xclip, sshfs, tailscale, nvim, tmux.
- Not installed: fd, bat, delta, pandoc, typst, yq, tig.
- Google Drive: prefer `rclone` over the Google Drive connector tools. Remote `dm:` is the company
  shared drive (team_drive set), e.g. `rclone lsf dm:path/`, `rclone copy file dm:path/`.
- My `tree` alias ignores venv/.venv/__pycache__/.git/node_modules/caches; `treeg` = `tree --gitignore`.
- `pgrep -f` / `pkill -f` / `ps | grep` match your own Bash tool shell, whose command line contains
  the pattern. Bracket one character so the pattern doesn't match itself: `pgrep -af '[m]y_node'`,
  `pkill -f '[m]y_node'`, `ps aux | grep '[m]y_node'`. Or use `pgrep -x`/`pkill -x` on the exact
  process name when `-f` isn't needed.

## Company devices (SSH)

- `~/.ssh/config` holds hosts for company robots/Orins: dm1, tf0–tf6, ahs5, gordon, orin1678,
  with `-usb` / `-wifi` / `-ap` / `-eth` variants.
- REFERENCE ONLY. Don't ssh, scp, sshfs, or ping these unless I've given permission for that
  specific purpose in the current conversation. Permission for one task doesn't carry over.

## Links

- Start every markdown link's text with the nerdfont mouse glyph `󰍽` (nf-md-mouse, U+F037D) and a
  space, inside the brackets so the glyph is clickable too, e.g.
  [󰍽 /tmp/claude-robofab/image.png](file:///tmp/claude-robofab/image.png). kitty only underlines
  links on hover, so the glyph is what marks them as clickable.
- Click-to-copy links get the copy glyph `󰆏` (nf-md-content_copy, U+F018F) instead, also inside
  the brackets: [󰆏 git push --force-with-lease](file:///copy/git%20push%20--force-with-lease). Keep the glyph
  out of the copied target; only the link text gets it.
- http/https links get the earth glyph `󰇧` (nf-md-earth, U+F01E7) instead, also inside the
  brackets: [󰇧 code.claude.com/docs](https://code.claude.com/docs). The session pins popup labels
  web pins the same way.
- Agent pane links (`file:///tmux/...`) get the monitor glyph `󰍹` (nf-md-monitor, U+F0379)
  instead, also inside the brackets: the [󰍹 robocore lighting agent](file:///tmux/robocore:2.1).

## Showing me files

- When you want me to look at a file from your scratchpad (image, plot, PDF, log), copy it to
  `/tmp/claude-<project>/<file>` first and give me that path. `<project>` is the repo or working
  dir basename, e.g. `/tmp/claude-robofab/image.png`. Never just say "it's in my scratchpad" or
  hand me the long scratchpad path.
- Whenever you show me a file or directory, write it as a markdown file link with the path as the
  text: `[/tmp/claude-robofab/image.png](file:///tmp/claude-robofab/image.png)`. These are
  clickable in my terminal; plain paths aren't.

## Click-to-copy commands

- Whenever you give me a command to run, show it as a click-to-copy link: link text is the command,
  target is `file:///copy/` + the command percent-encoded (spaces `%20`, `"` `%22`, `&` `%26`, `%`
  `%25`, `#` `%23`, `?` `%3F`, `(` `%28`, `)` `%29`, `[` `%5B`, `]` `%5D`, `<` `%3C`, `>` `%3E`;
  everything non-alphanumeric is safest encoded). Left-click copies it (kitty open-actions.conf →
  `~/.config/kitty/copy-text.sh`). Example:
  [git push --force-with-lease](file:///copy/git%20push%20--force-with-lease)
- In the link text, escape markdown-special characters (`[`, `]`, `` ` ``) so it renders; the
  target is what gets copied.
- One-liners only. For multi-line commands use a fenced code block, optionally followed by a
  copy link for the whole thing joined with `&&` or `;` if that's runnable.
- Works for any short text worth copying (paths, IDs, hashes), not just commands.

## Other Claude agents

- Speak when spoken to. Never message a sibling Claude session (SendMessage to a peer) unless I've asked
  you to, or you're replying to a message it sent you. Subagent <-> parent messages are always fine.
- When mentioning another Claude session to me, call it "the <session> <task> agent", linked to its
  pane: the [󰍹 robocore lighting agent](file:///tmux/robocore:2.1). Kitty routes `file:///tmux/` links
  to a pane jump (open-actions.conf). Never show the raw URL. Peer IDs like `robocore-3f` are for
  SendMessage only.
  The `relay` skill's `agents.py` maps peer IDs to tmux location and task.

## Worktrees

- Prefer to keep the canon directory of a repo on main and keep it fresh.
- Use worktrees under `<repo>/.claude/worktrees` for separate tasks with their own branches.
  - Always cd into the worktree you are working on.
  - Always name worktrees in a semantically comprehensible way, not just generic `agent1234...`.
    For example, `seg-autolabel` rather than `agent-a3f9c1`.
- Clean up worktrees and branches associated opportunistically.

## main / master

- Always ask me right before any operation that changes main/master itself: merging a PR into it,
  pushing/force-pushing to it, resetting or rebasing it, closing PRs that target it. Ask at the
  moment of the operation, even mid-plan.
- Branch work that only reads main is fine without asking: rebasing a feature branch onto main,
  merging main into a branch, pushing/force-pushing feature branches, retargeting PRs.
- Me describing how I want PRs organized or ordered ("merge X before Y") is NOT permission to
  merge. Do the prep (rebase branches, retarget, fix conflicts), then stop and ask before each merge.

## Code review

- In robocore and its vendees (repos that vendor robocore as `core/`: ahs, stereo_camera_playground,
  uarm_playground, terabase/{lander,robofab,telehandler,connector_robot}), do reviews with the repo's
  own reviewer agent, not a stock review agent or the generic `/code-review` skill.
  - Default is `code-change-reviewer` (from robocore's `.claude/agents/`). If the repo defines its
    own reviewer (e.g. telehandler `code-reviewer`, connector_robot `standards-compliance-reviewer`),
    prefer that one.
  - Pass it the original user request, as its description asks.
  - If the agent isn't offered as a `subagent_type` (e.g. it lives only in `core/.claude/agents/`),
    read its `.md` and run a general-purpose agent with that file as its instructions.

## Coworkers on GitHub (DavisMechatronics org)

When I name a coworker ("tag james for review", "assign evan"), map first name → login.
"Tag X for review" = `gh pr edit --add-reviewer <login>`.

- Avery Phimmasehn = `Aphimm`
- Cedric Jeanty = `cedricjeanty`
- Christian Stewart = `weaslepalace`
- Erik Cummins = `erikcummins`
- Evan Long = `elong42`
- James Deacon = `JamesDeacon314`
- Josh Bimson = `saftysquints` (also commits as `jlbimson`)
- Marc Grossman = `grossman83`
- Mike Corsetto = `corsetto`
- Me (Vivek) = `vivtrain`; review bot = `dm-review-bot`
- Outside the org (Terabase): Gregory Weitzel = `greg-weitzel-tbe`, Naveen Sankar = `naveen-sankar-tbe`
- Unknown: `everforgeai`
