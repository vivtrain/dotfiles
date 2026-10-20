# Global notes

Applies to every project. Drop notes below as plain bullets.

## PDFs / documents

- Company brand standards: `~/Documents/davis-mech_brand-guidelines.pdf` (3 pages: logo, color).
  Use it by default for any PDF I ask you to generate, unless I say otherwise.
  - Primary blues (titles, accents, backgrounds): Blue 1 `#163258`, Blue 2 `#395a87`
  - Accent greens, sparingly, never body text: Green 1 `#a0a538`, Green 2 `#d1d923`
  - Neutrals (backgrounds, body text, secondary titles): Dark grey `#1f1f1b`, Warm grey `#65665c`,
    Beige `#a6a696`, Cream `#d1d1bd`
  - Logo: don't recolor/stretch, min 0.75in high in print, clear space = height of the "M".
- Past reports live in `~/Documents/reports/` (made via headless Chrome HTML→PDF, or pypdf).

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

## Showing me files

- When you want me to look at a file from your scratchpad (image, plot, PDF, log), copy it to
  `/tmp/claude-<project>/<file>` first and give me that path. `<project>` is the repo or working
  dir basename, e.g. `/tmp/claude-robofab/image.png`. Never just say "it's in my scratchpad" or
  hand me the long scratchpad path.
- Whenever you show me a file or directory, write it as a markdown file link with the path as the
  text: `[/tmp/claude-robofab/image.png](file:///tmp/claude-robofab/image.png)`. These are
  clickable in my terminal; plain paths aren't.

## Worktrees

- Prefer to keep the canon directory of a repo on main and keep it fresh.
- Use worktrees under `<repo>/.claude/worktrees` for separate tasks with their own branches.
  - Always cd into the worktree you are working on.
  - Always name worktrees in a semantically comprehensible way, not just generic `agent1234...`.
    For example, `seg-autolabel` rather than `agent-a3f9c1`.
- Clean up worktrees and branches associated opportunistically.

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
