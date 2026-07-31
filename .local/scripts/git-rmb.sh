#!/usr/bin/env bash
# git-rmb — delete one or more branches locally and on their upstream remote.
#
#   local + tracked upstream  -> delete both
#   local only                -> delete the local branch
#   remote only               -> delete the remote branch
#
# Refuses main/master/the remote default branch. Confirms once, up front.
set -u

usage() { echo "usage: git rmb <branch>..." >&2; }

(($#)) || { usage; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "git rmb: not a git repository" >&2; exit 1; }

# --- protected branch: the remote's default, falling back to main/master ---
def=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || true
def=${def#origin/}
if [[ -z $def ]]; then
	for n in main master; do
		git show-ref --verify --quiet "refs/heads/$n" && { def=$n; break; }
	done
fi

cur=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || true

# --- one ls-remote per remote, cached ---
declare -A REMOTE_HEADS
has_remote_branch() { # <remote> <branch>
	local r=$1
	[[ -v REMOTE_HEADS[$r] ]] ||
		REMOTE_HEADS[$r]=$(git ls-remote --heads "$r" 2>/dev/null | sed 's#.*refs/heads/##')
	grep -qxF -- "$2" <<<"${REMOTE_HEADS[$r]}"
}

# --- plan ---
declare -a br=() has_local=() rmt=() rbr=() note=()
bad=0 switch_needed=0

for b in "$@"; do
	case $b in
	"$def" | main | master)
		echo "git rmb: refusing to delete protected branch '$b'" >&2
		bad=1
		continue
		;;
	esac
	for seen in ${br[@]+"${br[@]}"}; do [[ $seen == "$b" ]] && continue 2; done

	loc=0 rn='' rb='' nt=''
	git show-ref --verify --quiet "refs/heads/$b" && loc=1

	if ((loc)); then
		r=$(git config --get "branch.$b.remote" 2>/dev/null) || true
		m=$(git config --get "branch.$b.merge" 2>/dev/null) || true
		if [[ -n $r && $r != "." && -n $m ]]; then
			if has_remote_branch "$r" "${m#refs/heads/}"; then
				rn=$r rb=${m#refs/heads/}
			else
				nt="upstream $r/${m#refs/heads/} already gone"
			fi
		fi
		[[ $b == "$cur" ]] && switch_needed=1
	else
		if has_remote_branch origin "$b"; then
			rn=origin rb=$b
		else
			echo "git rmb: no branch '$b' locally or on origin" >&2
			bad=1
			continue
		fi
	fi

	br+=("$b") has_local+=("$loc") rmt+=("$rn") rbr+=("$rb") note+=("$nt")
done

((${#br[@]})) || exit $bad

# --- confirm once ---
echo "About to delete:"
for i in "${!br[@]}"; do
	what=''
	((has_local[i])) && what="local $(git rev-parse --short "${br[i]}")"
	[[ -n ${rmt[i]} ]] && what="${what:+$what + }${rmt[i]}/${rbr[i]}"
	[[ -n ${note[i]} ]] && what="$what  (${note[i]})"
	printf '  %-30s %s\n' "${br[i]}" "$what"
done
if ((switch_needed)); then
	[[ -n $def ]] || { echo "git rmb: '$cur' is checked out and no default branch found" >&2; exit 1; }
	echo "  (switching to $def first)"
fi

read -r -p "Proceed? [y/N] " ans </dev/tty
[[ $ans == [yY]* ]] || { echo aborted; exit 1; }

# --- execute ---
((switch_needed)) && { git switch "$def" || exit 1; }

declare -a unmerged=()
for i in "${!br[@]}"; do
	((has_local[i])) || continue
	git branch -d "${br[i]}" || unmerged+=("${br[i]}")
done

if ((${#unmerged[@]})); then
	echo "Not fully merged: ${unmerged[*]}"
	read -r -p "Force-delete ${#unmerged[@]} local branch(es)? [y/N] " ans </dev/tty
	if [[ $ans == [yY]* ]]; then
		git branch -D "${unmerged[@]}"
	else
		echo "kept local branch(es): ${unmerged[*]}"
	fi
fi

# one push per remote
declare -A todo=()
for i in "${!br[@]}"; do
	[[ -n ${rmt[i]} ]] && todo[${rmt[i]}]+=" ${rbr[i]}"
done
for r in "${!todo[@]}"; do
	# shellcheck disable=SC2086
	git push "$r" --delete ${todo[$r]}
done

exit $bad
