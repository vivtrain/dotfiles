#!/usr/bin/env -S python3 -I
"""UserPromptSubmit hook: run inline shell commands in a prompt, hand Claude the output.

Two syntaxes, anywhere in the prompt:
    $(cmd)      bash-style; nesting and quotes are fine: $(echo "$(date)")
    !`cmd`      Claude Code skill-style

Not run:
    \\$(cmd)     escaped
    `$(cmd)`    inside an inline code span (plain backticks, no leading !)
    ```...```   inside a fenced code block
    $((1+2))    arithmetic
    anything inside <pasted_content> blocks

Commands run in the session's cwd under bash, with ~/.bash_aliases sourced so your aliases
and functions work. The prompt itself is unchanged; outputs are attached as additionalContext.
"""
import json
import re
import subprocess
import sys

TIMEOUT_S = 30
MAX_CMDS = 10
MAX_OUT_CHARS = 8000

RUNNER = 'shopt -s expand_aliases; source ~/.bash_aliases >/dev/null 2>&1; eval "$1"'


def mask(s, start, end):
    return s[:start] + " " * (end - start) + s[end:]


def find_commands(prompt):
    m = prompt
    # Regions where nothing runs: pasted content and fenced code blocks.
    for pat in (r"<pasted_content\b.*?</pasted_content>", r"```.*?(?:```|\Z)"):
        for hit in re.finditer(pat, m, re.S):
            m = mask(m, *hit.span())

    found = []  # (position, command)
    # !`cmd` first, so its backticks aren't taken as a plain code span below.
    for hit in re.finditer(r"!`([^`\n]+)`", m):
        found.append((hit.start(), hit.group(1)))
        m = mask(m, *hit.span())
    # Plain inline code spans are prose about commands, not commands.
    for hit in re.finditer(r"`[^`\n]*`", m):
        m = mask(m, *hit.span())

    i = 0
    while (i := m.find("$(", i)) != -1:
        if (i > 0 and m[i - 1] == "\\") or m.startswith("$((", i):
            i += 2
            continue
        depth, j, quote = 1, i + 2, None
        while j < len(m) and depth:
            c = m[j]
            if quote:
                if c == "\\" and quote == '"':
                    j += 1
                elif c == quote:
                    quote = None
            elif c in "'\"":
                quote = c
            elif c == "\\":
                j += 1
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            j += 1
        if depth == 0 and (cmd := m[i + 2 : j - 1].strip()):
            found.append((i, cmd))
        i = j

    seen, cmds = set(), []
    for _, cmd in sorted(found):
        if cmd not in seen:
            seen.add(cmd)
            cmds.append(cmd)
    return cmds


def run(cmd, cwd):
    try:
        p = subprocess.run(
            ["bash", "-c", RUNNER, "inline-cmd", cmd],
            cwd=cwd or None, capture_output=True, text=True, timeout=TIMEOUT_S,
        )
        out, status = p.stdout + p.stderr, f"exit {p.returncode}"
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        status = f"timed out after {TIMEOUT_S}s"
    if len(out) > MAX_OUT_CHARS:
        out = out[:MAX_OUT_CHARS] + f"\n[... truncated, {len(out)} chars total]"
    return out.rstrip("\n"), status


def main():
    data = json.load(sys.stdin)
    cmds = find_commands(data.get("prompt", ""))
    if not cmds:
        return
    skipped = cmds[MAX_CMDS:]
    cmds = cmds[:MAX_CMDS]

    parts = [
        "The user's prompt contains inline shell commands, written as $(cmd) or !`cmd`. "
        "A UserPromptSubmit hook already ran them on the user's machine (bash, cwd "
        f"{data.get('cwd', '?')}, ~/.bash_aliases loaded) before this turn. Read each one in "
        "the prompt as standing for its output below:"
    ]
    for cmd in cmds:
        out, status = run(cmd, data.get("cwd"))
        parts.append(f"\n$ {cmd}    [{status}]\n```\n{out}\n```")
    if skipped:
        parts.append(f"\nNot run (over the {MAX_CMDS}-command limit): " + "; ".join(skipped))

    shown = ", ".join(cmds)
    msg = f"inline: ran {len(cmds)} command{'s' if len(cmds) != 1 else ''}: {shown}"
    if len(msg) > 200:
        msg = msg[:197] + "..."
    json.dump({
        "systemMessage": msg,
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": "\n".join(parts),
        },
    }, sys.stdout)


if __name__ == "__main__":
    main()
