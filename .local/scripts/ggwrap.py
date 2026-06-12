#!/usr/bin/env python3
"""
ggwrap.py — wrap git-graph output with hanging indentation.

Reads git-graph output on stdin, wraps long commit subjects to terminal
width so continuation lines align under the subject (past the hash), while
redrawing the graph lanes as colored vertical bars down the continuation.

Usage:
    git-graph --color always ... | ggwrap.py | less -R

Width is taken from $GGW_COLS if set, else the terminal size, else 100.
"""
import sys
import re
import os
import signal
import unicodedata
import shutil

# Let SIGPIPE behave normally so quitting the pager early doesn't traceback.
try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception:
    pass

ANSI = re.compile(r"\x1b\[[0-9;]*m")

# Glyphs that represent a continuing lane (redrawn as │ on wrapped lines).
# Corners/diagonals (╮ ╯ ╭ ╰ ─ / \) are intentionally excluded: they mark a
# one-row transition, not an ongoing lane, so they blank to spaces.
LANE = set("●○*│┼├┤╳")

RESET = "\x1b[0m"


def disp_width(s):
    """Display width of s, ignoring ANSI escapes, counting wide chars as 2."""
    s = ANSI.sub("", s)
    w = 0
    for ch in s:
        if unicodedata.combining(ch):
            continue
        w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return w


def parse_cells(line):
    """Return [(display_col, char), ...] for visible chars, skipping ANSI."""
    j, n, col, cells = 0, len(line), 0, []
    while j < n:
        m = ANSI.match(line, j)
        if m:
            j = m.end()
            continue
        ch = line[j]
        j += 1
        cells.append((col, ch))
        col += 0 if unicodedata.combining(ch) else (
            2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
        )
    return cells


def raw_index(line, target_col):
    """Raw string index at the given display column (ANSI-aware)."""
    j, n, col = 0, len(line), 0
    while j < n and col < target_col:
        m = ANSI.match(line, j)
        if m:
            j = m.end()
            continue
        ch = line[j]
        j += 1
        col += 0 if unicodedata.combining(ch) else (
            2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
        )
    return j


def lane_colors(line, upto_col):
    """Map {display_col: active_ansi_color} for lane glyphs before upto_col."""
    j, n, col, color, lanes = 0, len(line), 0, "", {}
    while j < n and col < upto_col:
        m = ANSI.match(line, j)
        if m:
            color = m.group(0)
            j = m.end()
            continue
        ch = line[j]
        j += 1
        if ch in LANE:
            lanes[col] = color
        col += 0 if unicodedata.combining(ch) else (
            2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
        )
    return lanes


def target_width():
    if os.environ.get("GGW_COLS"):
        try:
            return int(os.environ["GGW_COLS"])
        except ValueError:
            pass
    return shutil.get_terminal_size((100, 24)).columns


def process(line, cols):
    cells = parse_cells(line)

    # Hash column = first alphanumeric character on the line.
    hc = None
    for c, ch in cells:
        if ch.isalnum():
            hc = c
            break
    if hc is None:
        return [line]  # pure graph row (no commit text) — pass through

    # Subject start = first space after the contiguous hash run, +1 column.
    # Falls back to hash+8 if the layout is unexpected.
    ts, inhash = None, False
    for c, ch in cells:
        if c < hc:
            continue
        if ch.isalnum():
            inhash = True
            continue
        if inhash and ch == " ":
            ts = c + 1
            break
    if ts is None:
        ts = hc + 8

    ri = raw_index(line, ts)
    prefix_raw = line[:ri]
    rest_raw = line[ri:]

    # Word-wrap the (color-bearing) remainder to the available width.
    avail = max(10, cols - ts)
    cur, chunks = "", []
    for wd in rest_raw.split(" "):
        cand = wd if cur == "" else cur + " " + wd
        if disp_width(cand) <= avail:
            cur = cand
        else:
            if cur:
                chunks.append(cur)
            cur = wd
    if cur:
        chunks.append(cur)
    if not chunks:
        chunks = [""]

    out = [prefix_raw + chunks[0] + RESET]

    # Continuation prefix: lanes redrawn as colored │, hash region blanked.
    lanes = lane_colors(line, hc)
    cont = "".join(
        (lanes[x] + "│" + RESET) if x in lanes else " "
        for x in range(ts)
    )
    for c in chunks[1:]:
        out.append(cont + c + RESET)
    return out


def main():
    cols = target_width()
    w = sys.stdout.write
    try:
        for line in sys.stdin:
            for outline in process(line.rstrip("\n"), cols):
                w(outline + "\n")
    except BrokenPipeError:
        try:
            sys.stdout.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
