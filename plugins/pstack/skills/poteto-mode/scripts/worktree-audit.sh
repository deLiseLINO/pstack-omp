#!/usr/bin/env bash
# Read-only worktree prune audit. Classifies every git worktree by size, merge
# state, uncommitted work, and remote/PR state. Emits a table sorted by size
# with a suggested bucket. Never deletes anything; deletion stays a
# human-gated step in the playbook.
#
# Usage: worktree-audit.sh [-b|--base <ref>] [repo-path]
#   repo-path defaults to the current repo.
#   -b sets the ref the MERGED column checks against (e.g. origin/integration).
#   Without it the base is origin/HEAD, then origin/main, then origin/master.
#   origin/HEAD is the remote's default branch, not necessarily the branch PRs
#   merge into; pass -b when they differ.
set -u

base=""
while [ $# -gt 0 ]; do
	case "$1" in
	-b|--base) [ $# -ge 2 ] || { echo "error: $1 needs a ref" >&2; exit 2; }; base="$2"; shift 2 ;;
	-h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	-*) echo "error: unknown option: $1" >&2; exit 2 ;;
	*) break ;;
	esac
done

repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$repo" ] && { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd "$repo" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "error: not a git repo: $repo" >&2; exit 1; }

# Main worktree is the first entry; everything else is a candidate.
# Main worktree is the first entry; everything else is a candidate. Strip the
# record prefix rather than splitting fields so paths containing spaces survive.
if ! worktree_records=$(git worktree list --porcelain); then
	echo "could not inspect git worktrees" >&2
	exit 1
fi
main_wt=$(printf '%s\n' "$worktree_records" | awk '/^worktree /{sub(/^worktree /, ""); print; exit}')

if [ -z "$base" ]; then
	for cand in "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master; do
		[ -n "$cand" ] && git rev-parse --verify --quiet "$cand^{commit}" >/dev/null && { base="$cand"; break; }
	done
	[ -z "$base" ] && { echo "error: no base ref (origin/HEAD, origin/main, origin/master all missing); pass -b <ref>" >&2; exit 1; }
	echo "warn: no -b given; MERGED checks against $base" >&2
fi

# The base drives the merge check. The fetch is best-effort (stale is fine for
# a first pass) and runs before the check, since -b may name a branch not
# fetched yet. The explicit refspec creates it even in a single-branch clone.
case "$base" in
origin/*) git fetch origin "+refs/heads/${base#origin/}:refs/remotes/$base" --quiet 2>/dev/null \
	|| echo "warn: could not fetch $base; merged column may be stale" >&2 ;;
esac
git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { echo "error: base ref not found: $base" >&2; exit 1; }

# PR state by branch, fetched once as [{number, state, head}] with a lowercase
# state. Origin when its CLI can read this repo's PRs, otherwise gh. Empty when
# neither can.
scratch_dir="${TMPDIR:-$repo/.pstack-scratch}/worktree-audit"
mkdir -p "$scratch_dir"
prs=$(mktemp "$scratch_dir/prs.XXXXXX")
trap 'rm -f "$prs"' EXIT INT TERM
if command -v origin >/dev/null 2>&1 \
	&& raw=$(origin pr list --author "@me" --state all --limit 1000 \
		--json number,status,headRef 2>/dev/null); then
	printf '%s' "$raw" | jq '[.[] | {number, state: .status, head: .headRef}]' > "$prs" 2>/dev/null
elif raw=$(gh pr list --author "@me" --state all --limit 1000 \
	--json number,state,headRefName 2>/dev/null); then
	printf '%s' "$raw" | jq '[.[] | {number, state: (.state | ascii_downcase), head: .headRefName}]' > "$prs" 2>/dev/null
fi
[ -s "$prs" ] || echo "[]" > "$prs"

# omp keys each session tree by cwd, the path with $HOME stripped and "/" rewritten
# as "-". A chat launched inside a worktree lands in that worktree's own bucket, so
# scan both and nothing else; walking every bucket scales with total omp history
# instead of this repo's.
sessions="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/sessions"
bucket() { printf '%s/%s' "$sessions" "$(printf '%s' "${1#"$HOME"}" | sed 's#/#-#g')"; }
repo_bucket=$(bucket "$main_wt")
[ -d "$repo_bucket" ] || repo_bucket="$sessions"
now=$(date +%s)

echo "# base: $base"
printf "SIZE\tAGE\tMERGED\tDIRTY\tLOCKED\tINSPECT\tREMOTE\tPR\tLAST_CHAT\tBUCKET\tWORKTREE\n"

printf '%s\n' "$worktree_records" | awk '/^worktree /{sub(/^worktree /, ""); print}' | while IFS= read -r wt; do

	inspect=ok
	lock=$(printf '%s\n' "$worktree_records" | awk -v target="$wt" '
		BEGIN { RS=""; FS="\n" }
		$1 == "worktree " target {
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^locked/) {
					reason = substr($i, 8)
					print reason == "" ? "yes" : reason
					exit
				}
			}
		}')
	[ -z "$lock" ] && lock="-"
	[ "$wt" = "$main_wt" ] && continue

	size=$(du -sh "$wt" 2>/dev/null | awk '{print $1}')
	if ! head=$(git -C "$wt" rev-parse HEAD 2>/dev/null); then
		head=""
		inspect="head-error"
	fi
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age=$([ "$head_ts" -gt 0 ] 2>/dev/null && echo "$(( (now - head_ts) / 86400 ))d" || echo "?")

	# Squash-merged branches are not ancestors of the base, so PR state is the
	# real signal; merge-base only catches fast-forward/rebase merges.
	git merge-base --is-ancestor "$head" "$base" 2>/dev/null && merged=YES || merged=no

	# Distinguish real WIP (tracked edits) from disposable untracked scratch.
	if ! porcelain=$(git -C "$wt" status --porcelain 2>/dev/null); then
		dirty=error
		inspect="status-error"
	elif [ -z "$porcelain" ]; then dirty=clean
	elif printf '%s\n' "$porcelain" | grep -qv '^??'; then
		dirty="wip:$(printf '%s\n' "$porcelain" | grep -cv '^??')"
	else dirty="scratch:$(printf '%s\n' "$porcelain" | grep -c '^??')"; fi

	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "")
	if [ -z "$branch" ]; then remote=detached
	elif git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		[ "$(git -C "$wt" rev-parse "origin/$branch" 2>/dev/null)" = "$head" ] \
			&& remote=pushed \
			|| remote="ahead$(git -C "$wt" rev-list --count "origin/$branch..HEAD" 2>/dev/null)"
	else remote=no-remote; fi

	pr=$([ -n "$branch" ] && jq -r --arg b "$branch" \
		'.[] | select(.head==$b) | "#\(.number)/\(.state)"' "$prs" 2>/dev/null | head -1)
	[ -z "$pr" ] && pr="-"

	# Most recent chat whose transcript operated in this worktree. Match path
	# followed by "/" or a quote so glint-482 does not match glint-482-r37.
	last="-"; last_ts=0
	wt_bucket=$(bucket "$wt"); [ -d "$wt_bucket" ] || wt_bucket="$repo_bucket"
	if [ -d "$repo_bucket" ]; then
		f=$(rg -l -e "${wt}/" -e "${wt}\"" "$repo_bucket" "$wt_bucket" 2>/dev/null \
			| xargs -r stat -c '%Y %n' 2>/dev/null | sort -rn | head -1)
		if [ -n "$f" ]; then last_ts=$(echo "$f" | awk '{print $1}')
			last=$(date -d @"$last_ts" '+%Y-%m-%d' 2>/dev/null); fi
	fi
	recent=$([ "$last_ts" -gt 0 ] 2>/dev/null && [ $(( (now - last_ts) / 86400 )) -le 4 ] && echo yes || echo no)

	if [ "$inspect" != ok ]; then bucket=hold-error
	elif [ "$lock" != "-" ]; then bucket=hold-locked
	else
		case "$dirty" in
		error) bucket=hold-error ;;
		wip:*) bucket=hold-wip ;;
		*)
			case "$pr" in
			*OPEN*) bucket=hold-open-pr ;;
			*)
				if [ "$recent" = yes ]; then bucket=verify-recent-chat
				elif [ "$merged" = YES ] || [ "$pr" != "-" ]; then bucket=safe
				else bucket=review; fi ;;
			esac ;;
		esac
	fi

	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$bucket" "$wt"
done | sort -t$'\t' -k1,1 -rh

