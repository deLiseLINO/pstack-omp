#!/usr/bin/env bash
# Run against the generated audit, or pass an older script to prove regressions.
set -euo pipefail

PORT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
AUDIT=${1:-$PORT_DIR/../plugins/pstack/skills/poteto-mode/scripts/worktree-audit.sh}
case "$AUDIT" in /*) ;; *) AUDIT="$PWD/$AUDIT" ;; esac
for command in git jq; do
	command -v "$command" >/dev/null || { echo "missing dependency: $command" >&2; exit 1; }
done
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/worktree-audit-test.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
FIXTURE=$(cd "$FIXTURE" && pwd -P)
export HOME="$FIXTURE/home" TMPDIR="$FIXTURE/tmp"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR PI_CODING_AGENT_SESSION_DIR
export PI_CODING_AGENT_DIR="$FIXTURE/agent"
export REAL_STAT REAL_DATE
REAL_STAT=$(command -v stat)
REAL_DATE=$(command -v date)
mkdir -p "$HOME" "$TMPDIR" "$FIXTURE/bin" "$FIXTURE/bsd-bin"
export PATH="$FIXTURE/bin:$PATH"
REPO="$HOME/main repo"
git init -q "$REPO"
git -C "$REPO" config user.name 'Audit regression'
git -C "$REPO" config user.email audit@example.invalid
git -C "$REPO" config commit.gpgsign false
printf 'seed\n' > "$REPO/tracked"
git -C "$REPO" add tracked
git -C "$REPO" commit -qm seed
git -C "$REPO" branch -M main

add_worktree() {
	git -C "$REPO" worktree add -q -b "$1" "$HOME/$2" main
}
add_worktree open 'open worktree'
add_worktree draft 'draft worktree'
add_worktree merged 'merged worktree'
add_worktree locked 'locked worktree'
add_worktree dirty 'dirty worktree'
add_worktree recent 'recent [one].worktree'
add_worktree unrelated 'unrelated worktree'
add_worktree repo_recent 'repo session worktree'
add_worktree broken 'broken worktree'
OPEN="$HOME/open worktree"
DRAFT="$HOME/draft worktree"
MERGED="$HOME/merged worktree"
LOCKED="$HOME/locked worktree"
DIRTY="$HOME/dirty worktree"
RECENT="$HOME/recent [one].worktree"
UNRELATED="$HOME/unrelated worktree"
REPO_RECENT="$HOME/repo session worktree"
BROKEN="$HOME/broken worktree"
ABSOLUTE="$FIXTURE/absolute:worktree"
TEMPORARY="$TMPDIR/temp:worktree"
git -C "$REPO" worktree add -q -b absolute "$ABSOLUTE" main
git -C "$REPO" worktree add -q -b temporary "$TEMPORARY" main
git -C "$REPO" update-ref refs/remotes/origin/open HEAD
git -C "$REPO" worktree lock --reason 'keep this worktree' "$LOCKED"
printf 'edit\n' >> "$DIRTY/tracked"
printf 'squash-only change\n' >> "$MERGED/tracked"
git -C "$MERGED" add tracked
git -C "$MERGED" commit -qm 'unmerged head with merged PR'
printf 'gitdir: %s/missing\n' "$FIXTURE" > "$BROKEN/.git"

# HOME-relative bucket names are an independent runtime storage contract.
SESSIONS="$PI_CODING_AGENT_DIR/sessions"
RECENT_BUCKET="$SESSIONS/-recent [one].worktree"
mkdir -p "$RECENT_BUCKET" "$SESSIONS/-another-project"
printf '{"cwd":"%s"}\n' "$RECENT" > "$RECENT_BUCKET/recent chat.jsonl"
printf '{"cwd":"%s"}\n' "$UNRELATED" > "$SESSIONS/-another-project/unrelated.jsonl"
# Absolute cwd encoding strips the leading slash and maps separators and colons.
ABSOLUTE_BUCKET="$SESSIONS/--$(printf '%s' "${FIXTURE#/}" | tr '/' '-')-absolute-worktree--"
mkdir -p "$ABSOLUTE_BUCKET" "$SESSIONS/-tmp-temp-worktree"
printf '{"cwd":"%s"}\n' "$ABSOLUTE" > "$ABSOLUTE_BUCKET/absolute chat.jsonl"
printf '{"cwd":"%s"}\n' "$TEMPORARY" > "$SESSIONS/-tmp-temp-worktree/temp chat.jsonl"
EXPECTED_DATE=$(date '+%Y-%m-%d')

cat > "$FIXTURE/bin/origin" <<'SH'
#!/usr/bin/env bash
[ "$PR_PROVIDER" = origin ] || exit 1
printf '%s\n' '[{"number":1,"status":"OPEN","headRef":"open"},{"number":2,"status":"draft","headRef":"draft"},{"number":3,"status":"MERGED","headRef":"merged"}]'
SH
cat > "$FIXTURE/bin/gh" <<'SH'
#!/usr/bin/env bash
[ "$PR_PROVIDER" = gh ] || { echo 'unexpected gh fallback' >&2; exit 1; }
printf '%s\n' '[{"number":1,"state":"OPEN","headRefName":"open"},{"number":2,"state":"DRAFT","headRefName":"draft"},{"number":3,"state":"MERGED","headRefName":"merged"}]'
SH
# Exercise BSD fallback even on Linux. These wrappers only translate system
# timestamp operations; matching, PR parsing and classification stay real.
cat > "$FIXTURE/bsd-bin/stat" <<'SH'
#!/usr/bin/env bash
[ "$1" = -f ] && [ "$2" = '%m' ] || exit 1
"$REAL_STAT" -c '%Y' "$3" 2>/dev/null || "$REAL_STAT" -f '%m' "$3"
SH
cat > "$FIXTURE/bsd-bin/date" <<'SH'
#!/usr/bin/env bash
case "$1" in
-d) exit 1 ;;
-r) "$REAL_DATE" -r "$2" "$3" 2>/dev/null || "$REAL_DATE" -d "@$2" "$3" ;;
*) exec "$REAL_DATE" "$@" ;;
esac
SH
chmod +x "$FIXTURE/bin/origin" "$FIXTURE/bin/gh" "$FIXTURE/bsd-bin/stat" "$FIXTURE/bsd-bin/date"

fail() { printf 'worktree audit regression: %s\n' "$*" >&2; exit 1; }
assert_cell() {
	local path=$1 column=$2 expected=$3 actual
	actual=$(awk -F '\t' -v path="$path" -v column="$column" '
		$1 == "SIZE" { for (i = 1; i <= NF; i++) index_by_name[$i] = i; next }
		/^# / { next }
		index_by_name["WORKTREE"] && $(index_by_name["WORKTREE"]) == path { print $(index_by_name[column]); found++ }
		END { if (found != 1) exit 1 }
	' "$OUTPUT") || fail "$LABEL: missing or duplicate row: $path"
	[ "$actual" = "$expected" ] || fail "$LABEL: $path $column expected '$expected', got '$actual'"
}
assert_output() {
	awk -F '\t' '
		/^# / { next }
		$1 == "SIZE" { if (NF != 11) exit 1; header++; next }
		{ if (NF != 11 || $1 == "") exit 1; rows++ }
		END { if (header != 1 || rows != 11) exit 1 }
	' "$OUTPUT" || fail "$LABEL: expected eleven aligned columns and eleven candidate rows"
	assert_cell "$OPEN" PR '#1/open'
	assert_cell "$OPEN" REMOTE pushed
	assert_cell "$OPEN" BUCKET hold-open-pr
	assert_cell "$DRAFT" PR '#2/draft'
	assert_cell "$DRAFT" BUCKET hold-open-pr
	assert_cell "$MERGED" PR '#3/merged'
	assert_cell "$MERGED" MERGED no
	assert_cell "$MERGED" BUCKET safe
	assert_cell "$LOCKED" LOCKED 'keep this worktree'
	assert_cell "$LOCKED" INSPECT ok
	assert_cell "$LOCKED" BUCKET hold-locked
	assert_cell "$DIRTY" DIRTY wip:1
	assert_cell "$DIRTY" BUCKET hold-wip
	assert_cell "$BROKEN" INSPECT status-error
	assert_cell "$BROKEN" DIRTY error
	assert_cell "$BROKEN" BUCKET hold-error
	assert_cell "$RECENT" LAST_CHAT "$EXPECTED_DATE"
	assert_cell "$RECENT" BUCKET verify-recent-chat
	assert_cell "$UNRELATED" LAST_CHAT '-'
	assert_cell "$UNRELATED" BUCKET safe
	assert_cell "$REPO_RECENT" LAST_CHAT "$REPO_CHAT_DATE"
	assert_cell "$REPO_RECENT" BUCKET "$REPO_CHAT_BUCKET"
	assert_cell "$RECENT" LOCKED '-'
	assert_cell "$RECENT" INSPECT ok
	assert_cell "$RECENT" REMOTE no-remote
	assert_cell "$RECENT" AGE 0d
	assert_cell "$ABSOLUTE" LAST_CHAT "$EXPECTED_DATE"
	assert_cell "$ABSOLUTE" BUCKET verify-recent-chat
	assert_cell "$TEMPORARY" LAST_CHAT "$EXPECTED_DATE"
	assert_cell "$TEMPORARY" BUCKET verify-recent-chat
}
run_audit() {
	LABEL=$1
	OUTPUT="$FIXTURE/$LABEL.tsv"
	bash "$AUDIT" -b main "$REPO" > "$OUTPUT" || fail "$LABEL: audit exited unsuccessfully"
	assert_output
	printf 'worktree audit regression: %s PASS\n' "$LABEL"
}
REPO_CHAT_DATE='-'
REPO_CHAT_BUCKET=safe
for PR_PROVIDER in origin gh; do
	export PR_PROVIDER
	run_audit "native-$PR_PROVIDER-no-repo-bucket"
	PATH="$FIXTURE/bsd-bin:$PATH" run_audit "bsd-$PR_PROVIDER-no-repo-bucket"
done
# A repo-scoped session may mention a worktree whose own bucket is absent.
mkdir -p "$SESSIONS/-main repo"
printf '{"cwd":"%s"}\n' "$REPO_RECENT" > "$SESSIONS/-main repo/repo chat.jsonl"
REPO_CHAT_DATE=$EXPECTED_DATE
REPO_CHAT_BUCKET=verify-recent-chat
run_audit 'repo-bucket'
# TMPDIR wins over HOME when both contain a cwd.
LABEL=temp-priority
OUTPUT="$FIXTURE/$LABEL.tsv"
HOME="$TMPDIR" bash "$AUDIT" -b main "$REPO" > "$OUTPUT" || fail "$LABEL: audit exited unsuccessfully"
assert_cell "$TEMPORARY" LAST_CHAT "$EXPECTED_DATE"
assert_cell "$TEMPORARY" BUCKET verify-recent-chat
# An explicit directory holds transcripts directly, without cwd buckets.
DIRECT="$FIXTURE/direct sessions"
mkdir -p "$DIRECT"
for path in "$RECENT" "$REPO_RECENT" "$ABSOLUTE" "$TEMPORARY"; do
	printf '{"cwd":"%s"}\n' "$path"
done > "$DIRECT/direct chat.jsonl"
export PI_CODING_AGENT_SESSION_DIR="$DIRECT"
export PI_CODING_AGENT_DIR="$FIXTURE/unused-agent"
run_audit 'explicit-transcript-directory'
printf 'worktree audit regression: PASS\n'
