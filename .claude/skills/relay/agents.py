#!/usr/bin/env python3
"""List live Claude sessions with their tmux location and task, optionally ranked by a query.

Joins ~/.claude/sessions/*.json (peer name, status, tmux pane) with `tmux list-panes`
(session, window index/name, pane title = Claude's task title, cwd) and git branch.

  agents.py                 # all agents
  agents.py lighting        # ranked by how many fields match each term
  agents.py --json [terms]  # machine-readable
"""
import json, os, re, subprocess, sys
from pathlib import Path

SESSIONS = Path.home() / ".claude" / "sessions"
FMT = "\t".join(["#{pane_id}", "#{session_name}", "#{window_index}", "#{window_name}",
                 "#{automatic-rename}", "#{pane_index}", "#{pane_title}", "#{pane_current_path}"])


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def tmux_panes():
    try:
        out = subprocess.run(["tmux", "list-panes", "-a", "-F", FMT],
                             capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return {}
    panes = {}
    for line in out.splitlines():
        pid, sess, widx, wname, auto, pidx, title, path = line.split("\t")
        panes[pid] = dict(session=sess, window=widx, pane=pidx, path=path,
                          # auto-renamed windows are just "<path>  <cmd>": noise, drop them
                          window_name="" if auto == "1" else wname,
                          # Claude sets the pane title to "<spinner/✳> <task title>"
                          title=re.sub(r"^\W+", "", title).strip())
    return panes


def branch(path):
    try:
        return subprocess.run(["git", "-C", path, "branch", "--show-current"],
                              capture_output=True, text=True, timeout=2).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def short(path):
    home = str(Path.home())
    path = path.replace(home, "~", 1) if path.startswith(home) else path
    return path.replace("~/DavisMechatronics/", "")


def agents():
    panes, me = tmux_panes(), os.environ.get("TMUX_PANE", "")
    rows = []
    for f in SESSIONS.glob("*.json"):
        try:
            s = json.loads(f.read_text())
        except (OSError, ValueError):
            continue
        if not s.get("name") or not alive(s.get("pid", 0)):
            continue
        pane_id = (s.get("tmux") or "").rsplit(".", 1)[-1]
        p = panes.get(pane_id, {})
        path = p.get("path") or s.get("cwd", "")
        wt = re.search(r"/\.claude/worktrees/([^/]+)", path)
        rows.append(dict(
            name=s["name"], status=s.get("status", "?"), me=bool(me) and pane_id == me,
            where=f"{p['session']}:{p['window']}.{p['pane']}" if p else (s.get("tmux") or "-"),
            window_name=p.get("window_name", ""), title=p.get("title", ""),
            dir=short(path), worktree=wt.group(1) if wt else "", branch=branch(path),
            pane_id=pane_id, session_id=s.get("sessionId", "")))
    return sorted(rows, key=lambda r: r["where"])


def score(row, terms):
    hay = " ".join(str(row[k]) for k in
                   ("name", "where", "window_name", "title", "dir", "worktree", "branch")).lower()
    return sum(t in hay for t in terms)


def main(argv):
    as_json = "--json" in argv
    terms = [a.lower() for a in argv if a != "--json"]
    rows = agents()
    if terms:
        for r in rows:
            r["score"] = score(r, terms)
        hits = [r for r in rows if r["score"]]
        rows = sorted(hits, key=lambda r: -r["score"]) if hits else rows
        if not hits:
            print(f"# no match for {' '.join(terms)!r}; showing all", file=sys.stderr)
    if as_json:
        print(json.dumps(rows, indent=1))
        return
    for r in rows:
        label = f"[{r['window_name']}] " if r["window_name"] else ""
        loc = r["worktree"] and f"wt:{r['worktree']}" or r["dir"]
        if r["branch"]:
            loc += f" @{r['branch']}"
        me = "  (you)" if r["me"] else ""
        print(f"{r['name']:<14} {r['status']:<5} file:///tmux/{r['where']:<13} {label}{r['title']}  — {loc}{me}")


if __name__ == "__main__":
    main(sys.argv[1:])
