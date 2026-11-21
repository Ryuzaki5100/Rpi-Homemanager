#!/usr/bin/env bash
# lh-sync — version the LearnHarness learning record across machines.
#
# The data directory is a git checkout of the private learnharness-data
# repository. This helper never auto-merges: a remote change that collides
# with local work is reported and the caller is expected to resolve it.
set -euo pipefail

REMOTE="${LH_SYNC_REMOTE:-git@github.com:Ryuzaki5100/learnharness-data.git}"
BRANCH="${LH_SYNC_BRANCH:-main}"
DATA_DIR="${LH_DATA_DIR:-$HOME/learning/learnharness-data}"
ACTIVITY_URL="${LH_SYNC_ACTIVITY_URL:-http://127.0.0.1:4747/api/activity}"

info() { printf 'lh-sync: %s\n' "$*" >&2; }
result() { printf '%s\n' "$*"; }

git_dir() { git -C "$DATA_DIR" "$@"; }

in_repo() { [ -d "$DATA_DIR/.git" ]; }

ensure_repo() {
	if in_repo; then
		return 0
	fi
	if [ -e "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
		info "$DATA_DIR exists but is not a git repository"
		return 1
	fi
	mkdir -p "$(dirname "$DATA_DIR")"
	info "cloning $REMOTE into $DATA_DIR"
	git clone --branch "$BRANCH" "$REMOTE" "$DATA_DIR" >/dev/null 2>&1 || {
		info "clone failed — is the private repository readable by this host?"
		return 1
	}
}

LOCK_DIR=""

acquire_lock() {
	LOCK_DIR="$DATA_DIR/.git/lh-sync.lock"
	if ! mkdir "$LOCK_DIR" 2>/dev/null; then
		info "another lh-sync is running"
		exit 4
	fi
	trap 'rmdir "${LOCK_DIR:-}" 2>/dev/null || true' EXIT INT TERM
}

dirty_count() {
	git_dir status --porcelain | wc -l | tr -d ' '
}

upstream() { printf 'origin/%s' "$BRANCH"; }

read_ahead_behind() {
	BEHIND="$(git_dir rev-list --count "HEAD..$(upstream)")"
	AHEAD="$(git_dir rev-list --count "$(upstream)..HEAD")"
}

fetch() {
	git_dir fetch --quiet origin "$BRANCH"
}

push_commits() {
	local ahead="$1"
	git_dir push --quiet origin "HEAD:$BRANCH"
	result "pushed $ahead commit(s)"
}

cmd_init() {
	ensure_repo
	result "$DATA_DIR"
}

cmd_status() {
	if ! in_repo; then
		result "missing"
		return 0
	fi
	local dirty
	dirty="$(dirty_count)"
	read_ahead_behind

	case "$dirty:$BEHIND:$AHEAD" in
	0:0:0) result "clean" ;;
	0:0:*) result "ahead $AHEAD" ;;
	0:*:0) result "behind $BEHIND" ;;
	0:*:*) result "diverged $AHEAD/$BEHIND" ;;
	*:0:0) result "dirty $dirty" ;;
	*:0:*) result "dirty $dirty, ahead $AHEAD" ;;
	*:*:*) result "dirty $dirty, diverged $AHEAD/$BEHIND" ;;
	*) result "dirty $dirty, behind $BEHIND" ;;
	esac
}

do_pull() {
	fetch
	local dirty
	dirty="$(dirty_count)"
	read_ahead_behind

	if [ "$BEHIND" -gt 0 ] && [ "$dirty" -gt 0 ]; then
		info "refusing to pull: the remote has $BEHIND new commit(s) and this tree has $dirty change(s)"
		git_dir status --short | sed 's/^/  /' >&2
		info "run 'lh-sync push' after the remote change is resolved, or commit by hand"
		return 2
	fi

	if [ "$BEHIND" -gt 0 ]; then
		if ! git_dir merge --ff-only "$(upstream)" >/dev/null 2>&1; then
			info "refusing to pull: histories diverged (local $AHEAD, remote $BEHIND)"
			return 3
		fi
		result "fast-forwarded $BEHIND commit(s)"
		return 0
	fi

	if [ "$AHEAD" -gt 0 ]; then
		push_commits "$AHEAD"
		return 0
	fi

	if [ "$dirty" -gt 0 ]; then
		result "local changes not yet committed ($dirty file(s))"
		return 0
	fi
	result "already up to date"
}

do_push() {
	local dirty
	dirty="$(dirty_count)"
	if [ "$dirty" -gt 0 ]; then
		git_dir add -A
		git_dir commit --quiet -m "sync: $(hostname -s 2>/dev/null || hostname) $(date -u +%Y%m%dT%H%M%SZ)"
		result "committed $dirty file(s)"
	fi
	read_ahead_behind
	if [ "$AHEAD" -eq 0 ]; then
		result "nothing to push"
		return 0
	fi
	if ! git_dir push --quiet origin "HEAD:$BRANCH" 2>/dev/null; then
		info "push refused: the remote has newer commits; run 'lh-sync pull' where the history can be reconciled"
		return 3
	fi
	result "pushed $AHEAD commit(s)"
}

cmd_pull() {
	ensure_repo
	acquire_lock
	do_pull
}

cmd_push() {
	ensure_repo
	acquire_lock
	do_push
}

cmd_cycle() {
	if server_busy; then
		result "busy"
		return 0
	fi
	ensure_repo
	acquire_lock
	do_push || info "push did not complete; attempting to fast-forward"
	fetch
	read_ahead_behind
	if [ "$BEHIND" -gt 0 ]; then
		do_pull
	else
		cmd_status
	fi
}

server_busy() {
	local body
	body="$(curl -fsS --max-time 2 "$ACTIVITY_URL" 2>/dev/null)" || return 1
	case "$body" in
	*'"id"'*) return 0 ;;
	*) return 1 ;;
	esac
}

usage() {
	cat <<EOF
usage: lh-sync <init|pull|push|cycle|status>

  init    clone the data repository if it is missing
  pull    fast-forward (or push local commits); refuse when the remote moved
          and the working tree has unresolved changes
  push    commit everything and push
  cycle   skip while the local server is busy, then push and fast-forward
  status  one line: clean | dirty N | ahead N | behind N | diverged A/B

Environment: LH_DATA_DIR, LH_SYNC_REMOTE, LH_SYNC_BRANCH, LH_SYNC_ACTIVITY_URL
EOF
}

case "${1:-}" in
init) cmd_init ;;
pull) cmd_pull ;;
push) cmd_push ;;
cycle) cmd_cycle ;;
status) cmd_status ;;
*) usage; exit 64 ;;
esac
