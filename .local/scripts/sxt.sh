#!/usr/bin/env bash
# sxt — S-expression -> `tree`-style block. Args or stdin (quote it: parens are shell syntax).
#
#   sxt '(root (a a1 a2) b (c (c1 c1x)))'
#   root
#   ├── a
#   │   ├── a1
#   │   └── a2
#   ├── b
#   └── c
#       └── c1
#           └── c1x
#
# {} and [] work as parens and usually need no quoting, since bash leaves them alone:
#   sxt {root {a a1 a2} b {c {c1 c1x}}}
#   sxt [root [a a1 a2] b [c [c1 c1x]]]
# Unquoted, bash still gets first look: {a,b} and {1..3} brace-expand, and a word that is
# itself a complete [...] (e.g. [h], [ab]) is a glob that can match a filename in the cwd.
#
# A list's head is the node, the rest are its children. Bare atoms are leaves.
# () is the empty tree: alone it prints nothing, as a child it adds nothing.
# Strings: "my node" or 'my node' is one atom, spaces and brackets kept ("" and " " are
# nodes too); \" and \\ escape inside "...". Bash strips quotes first, so single-quote the
# whole expression to use them: sxt '[a "my node" " " "(x)"]'
# Several top-level expressions print as several trees.

die() { echo "sxt: $*" >&2; exit 1; }

if (($#)); then s="$*"; else s=$(cat); fi
s=${s//$'\n'/ }; s=${s//$'\t'/ }

# Tokenize: ( [ { open, ) ] } close, "..." / '...' are string atoms (keep spaces and
# brackets; \" and \\ escape inside "..."), anything else up to a space/bracket/quote is an atom.
# kind[] marks each token: o(pen), c(lose), a(tom), so a string "(" stays an atom.
declare -a tok kind
len=${#s} j=0
while ((j < len)); do
  c=${s:j:1}
  case $c in
    ' ') ((++j)) ;;
    '('|'['|'{') tok+=("$c"); kind+=(o); ((++j)) ;;
    ')'|']'|'}') tok+=("$c"); kind+=(c); ((++j)) ;;
    '"'|"'")
      q=$c a= closed=0; ((++j))
      while ((j < len)); do
        c=${s:j:1}
        if [[ $c == "$q" ]]; then closed=1; ((++j)); break; fi
        if [[ $q == '"' && $c == '\' ]] && ((j + 1 < len)); then ((++j)); c=${s:j:1}; fi
        a+=$c; ((++j))
      done
      ((closed)) || die "unterminated $q string"
      tok+=("$a"); kind+=(a) ;;
    *)
      a=
      while ((j < len)); do
        c=${s:j:1}
        case $c in ' '|'('|')'|'['|']'|'{'|'}'|'"'|"'") break ;; esac
        a+=$c; ((++j))
      done
      tok+=("$a"); kind+=(a) ;;
  esac
done

declare -a name kids roots stack
n=0 want_head=0
for i in "${!tok[@]}"; do
  case ${kind[i]} in
    o)
      ((want_head)) && die "list head must be an atom, not a list (token $((i + 1)))"
      want_head=1 ;;
    c)
      if ((want_head)); then want_head=0; continue; fi  # () is the empty tree: no node
      ((${#stack[@]})) || die "unmatched '${tok[i]}' (token $((i + 1)))"
      unset 'stack[-1]' ;;
    a)
      name[n]=${tok[i]}; kids[n]=
      if ((${#stack[@]})); then kids[stack[-1]]+=" $n"; else roots+=("$n"); fi
      ((want_head)) && { stack+=("$n"); want_head=0; }
      ((n++)) ;;
  esac
done
((want_head || ${#stack[@]})) && die "unclosed '('"

draw() {  # <node> <prefix>
  local -a k=(${kids[$1]})
  local j last
  for j in "${!k[@]}"; do
    last=$(( j == ${#k[@]} - 1 ))
    if ((last)); then
      printf '%s└── %s\n' "$2" "${name[k[j]]}"; draw "${k[j]}" "$2    "
    else
      printf '%s├── %s\n' "$2" "${name[k[j]]}"; draw "${k[j]}" "$2│   "
    fi
  done
}

for r in "${roots[@]}"; do
  printf '%s\n' "${name[r]}"
  draw "$r" ""
done
