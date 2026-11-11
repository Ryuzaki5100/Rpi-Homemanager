#!/bin/sh
# Bring the GitHub copy up to date and optionally commit + push local changes.
#
#   sync.sh                        pull only (fast-forward)
#   sync.sh -m "message"           pull, commit everything, push
#   sync.sh -m "message" --no-push pull and commit locally
#
# Deliberately conservative: fast-forward pulls only, no force, no reset, and it
# refuses to commit unless you supply a message. Studio-side script changes are
# NOT handled here - the agent compares Studio against disk first.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

message=
do_push=1
while [ $# -gt 0 ]; do
	case "$1" in
		-m)
			[ $# -ge 2 ] || { echo "sync: -m needs a message" >&2; exit 2; }
			message=$2
			shift 2
			;;
		--no-push)
			do_push=0
			shift
			;;
		-h|--help)
			echo "usage: sync.sh [-m message] [--no-push]"
			exit 0
			;;
		*)
			echo "sync: unknown argument $1" >&2
			exit 2
			;;
	esac
done

branch=$(git rev-parse --abbrev-ref HEAD)
git fetch --quiet origin "$branch" || { echo "sync: cannot reach origin" >&2; exit 1; }

set -- $(git rev-list --left-right --count "origin/$branch...HEAD")
behind=$1
ahead=$2
if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
	echo "sync: local and origin/$branch have diverged; resolve manually. Refusing to force." >&2
	exit 1
fi

if [ "$behind" -gt 0 ]; then
	echo "sync: pulling $behind commit(s) from origin/$branch"
	git pull --ff-only
fi

if [ -n "$(git status --porcelain)" ]; then
	if [ -z "$message" ]; then
		echo "sync: working tree has uncommitted changes; rerun with -m \"message\" to commit them" >&2
		git status --short
		exit 1
	fi
	git add -A
	git commit -m "$message"
fi

if [ "$do_push" -eq 1 ]; then
	git push origin "$branch"
fi

git log --oneline -1
