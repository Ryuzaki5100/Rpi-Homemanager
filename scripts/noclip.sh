#!/bin/sh
# noclip — vault-driven multi-agent dispatcher for a Rojo/Roblox project.
#
# The vault (an Obsidian folder, git-tracked) is the shared blackboard: it holds
# the task queue, the role contract and the run log. This script is the only
# scheduler. It claims a task by moving the note (atomic on one filesystem),
# dispatches one `opencode run` process per task, and serialises everything that
# touches the live Studio session.
#
# Lanes:
#   files   — can run N at a time, each in its own git worktree
#   studio  — strictly one at a time, always in the main checkout, because Rojo
#             is wired to that directory and Studio is a single mutable resource
#
# Usage: noclip <command> [args]   (see `noclip help`)
set -eu

VERSION="0.1.0"

say()  { printf '%s\n' "$*"; }
warn() { printf 'noclip: %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

# ---------------------------------------------------------------- configuration

CONF=
REPO=
VAULT=
JOBS=
WORKTREES=
OPENCODE_BIN=
FORMAT=
LOCK_WAIT=

conf_get() {
	[ -n "$CONF" ] || return 1
	sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$CONF" | sed -n '1p'
}

load_config() {
	# Walk up from the working directory: .noclip marks the project root, the
	# first roblox.json is a fallback root. A project config always beats a
	# session-wide NOCLIP_REPO, so `noclip` run from the wrong shell still
	# targets the repository it is standing in.
	dir=$(pwd)
	while [ "$dir" != "/" ]; do
		if [ -f "$dir/.noclip" ]; then
			CONF="$dir/.noclip"
			break
		fi
		if [ -z "$REPO" ] && [ -f "$dir/roblox.json" ]; then
			REPO="$dir"
		fi
		dir=$(dirname "$dir")
	done
	REPO="${REPO:-${NOCLIP_REPO:-$(pwd)}}"

	# Order: project config > environment > default.
	pick() {
		v=$(conf_get "$1" 2>/dev/null || true)
		[ -n "$v" ] || eval "v=\${$2:-}"
		printf '%s' "$v"
	}

	JOBS=$(pick jobs NOCLIP_JOBS)
	WORKTREES=$(pick worktrees NOCLIP_WORKTREES)
	OPENCODE_BIN=$(pick opencode NOCLIP_OPENCODE)
	FORMAT=$(pick format NOCLIP_FORMAT)
	LOCK_WAIT=$(pick lock_wait NOCLIP_LOCK_WAIT)

	JOBS="${JOBS:-2}"
	WORKTREES="${WORKTREES:-1}"
	OPENCODE_BIN="${OPENCODE_BIN:-opencode}"
	FORMAT="${FORMAT:-default}"
	LOCK_WAIT="${LOCK_WAIT:-600}"

	VAULT=$(pick vault NOCLIP_VAULT)
	VAULT="${VAULT:-$HOME/roblox/noclip-vault}"
	case "$VAULT" in
	/*) ;;
	*)
		parent="$(cd "$REPO" && cd "$(dirname "$VAULT")" 2>/dev/null && pwd)" ||
			parent="$(cd "$REPO" && pwd)"
		VAULT="$parent/$(basename "$VAULT")"
		;;
	esac

	[ -d "$VAULT" ] || die "vault not found: $VAULT (run 'noclip init' or set NOCLIP_VAULT)"
	[ -d "$REPO/.git" ] || die "not a git repository: $REPO"

	BACKLOG="$VAULT/40-tasks/backlog"
	ACTIVE="$VAULT/40-tasks/active"
	DONE="$VAULT/40-tasks/done"
	LOGS="$VAULT/50-log"
	LOCKS="$VAULT/.locks"
	WORKTREE_ROOT="$REPO/.noclip-worktrees"
	mkdir -p "$BACKLOG" "$ACTIVE" "$DONE" "$LOGS" "$LOCKS"
}

# ------------------------------------------------------------------ frontmatter

# fm <file> <key> — first value of a key inside the leading --- block.
fm() {
	awk -v key="$2" '
		NR == 1 && $0 != "---" { exit }
		NR > 1 && $0 == "---" { exit }
		NR > 1 {
			line = $0
			sub(/^[ \t]*/, "", line)
			if (index(line, key ":") == 1) {
				v = substr(line, length(key) + 2)
				sub(/^[ \t]+/, "", v)
				print v
				exit
			}
		}
	' "$1"
}

# set_status <file> <status> — rewrites only the frontmatter status line.
set_status() {
	tmp="$1.tmp.$$"
	awk -v s="$2" '
		NR == 1 { print; next }
		/^---$/ && !closed { print; closed = 1; next }
		!closed && /^status:/ { print "status: " s; next }
		{ print }
	' "$1" >"$tmp" && mv "$tmp" "$1"
}

task_id() {
	fm "$1" id | tr -d '[:space:]'
}

# ---------------------------------------------------------------- studio mutex

studio_lock() {
	deadline=$(( $(date +%s) + LOCK_WAIT ))
	while ! mkdir "$LOCKS/studio" 2>/dev/null; do
		if [ "$(date +%s)" -ge "$deadline" ]; then
			return 1
		fi
		sleep 2
	done
	printf '%s\n' "$$" >"$LOCKS/studio/pid"
}

studio_unlock() {
	rm -rf "$LOCKS/studio"
}

# ---------------------------------------------------------------------- init

cmd_init() {
	vault="" repo=""
	while [ $# -gt 0 ]; do
		case "$1" in
		--vault) vault=${2:-}; shift 2 ;;
		--repo) repo=${2:-}; shift 2 ;;
		*) die "init: unknown argument $1" ;;
		esac
	done
	vault=${vault:-${NOCLIP_VAULT:-$HOME/roblox/noclip-vault}}
	repo=${repo:-${NOCLIP_REPO:-$PWD}}

	mkdir -p "$vault"/00-brief "$vault"/10-design "$vault"/20-assets \
		"$vault"/30-audio "$vault"/40-tasks/backlog "$vault"/40-tasks/active \
		"$vault"/40-tasks/done "$vault"/50-log "$vault"/90-decisions \
		"$vault"/templates "$vault/.locks"

	map="$vault/README.md"
	if [ -f "$map" ]; then
		say "kept:   $map"
	else
		cat >"$map" <<'EOF'
---
tags: [moc]
---

# Vault map

| Folder | Owner | Holds |
|---|---|---|
| `00-brief/` | human + designer | pillars, audience, scope |
| `10-design/` | designer | systems, loops, economy |
| `20-assets/` | asset-smith | manifests, style anchors, prompts |
| `30-audio/` | audio | cue sheets, loudness, licences |
| `40-tasks/` | librarian + noclip | the queue: backlog → active → done |
| `50-log/` | noclip | one append-only log per run |
| `90-decisions/` | anyone | ADRs: context, decision, consequences |
| `templates/` | librarian | note shapes |
EOF
		say "created: $map"
	fi

	new="$vault/AGENTS.md"
	if [ -f "$new" ]; then
		say "kept:   $new"
	else
		cat >"$new" <<'EOF'
# Vault contract

This vault is the shared memory and work queue for a Roblox project. Agents read
it; `noclip` schedules from it. Nothing here is generated prose — if a note does
not change a decision, delete it.

## Roles

| Agent | Owns | Writes | Lane |
|---|---|---|---|
| `librarian` | the queue and the record | `40-tasks/`, `90-decisions/` | files |
| `designer` | game design | `10-design/`, `00-brief/` | files |
| `scripter` | Luau | `src/` | files |
| `asset-smith` | world + assets | `20-assets/`, Studio instances | studio |
| `audio` | sound | `30-audio/`, `Sound` instances | files → studio |
| `qa` | verification | `50-log/` only | studio |
| `builder` | integration + release | merges, place file | files |

## Task note

```markdown
---
id: 0007-inventory-ui
title: Inventory HUD panel
agent: asset-smith
lane: studio
status: backlog
priority: 3
depends:
acceptance: panel opens on Tab, 3 slots, no console errors
---
## Intent
## Log
```

- `id` is the filename stem. `agent` must be a role in the table above.
- `lane: studio` means the task touches the live DataModel. Only one runs at a
  time; `noclip` enforces it with `40-tasks/../.locks/studio`.
- `acceptance` is a single line a `qa` run can fail unambiguously.
- A blocked task gets `status: blocked` and a `## Blocked` section saying what is
  missing. It goes back to `backlog/`; it is never quietly dropped.

## Rules

1. One note, one outcome.
2. Never mark a task `done` by hand — `noclip` moves it when the agent exits 0.
3. Never edit another role's folder.
4. Every asset and sound gets a source, a licence, and a manifest row.
5. Studio writes are serialised. If you are not the lock holder, wait.
EOF
		say "created: $new"
	fi

	tmpl="$vault/templates/task.md"
	if [ ! -f "$tmpl" ]; then
		cat >"$tmpl" <<'EOF'
---
id: NNNN-slug
title: One sentence outcome
agent: scripter
lane: files
status: backlog
priority: 5
depends:
acceptance:
---
## Intent

## Log
EOF
		say "created: $tmpl"
	fi

	dec="$vault/templates/decision.md"
	if [ ! -f "$dec" ]; then
		cat >"$dec" <<'EOF'
---
date: YYYY-MM-DD
status: accepted
---
# NNNN — Title

## Context

## Decision

## Consequences
EOF
		say "created: $dec"
	fi

	gi="$vault/.gitignore"
	if [ ! -f "$gi" ]; then
		printf '%s\n' ".locks/" ".trash/" ".worktrees/" ".DS_Store" ".obsidian/workspace*" >"$gi"
		say "created: $gi"
	fi

	if [ ! -d "$vault/.git" ]; then
		git -C "$vault" init -q
		git -C "$vault" add -A
		git -C "$vault" commit -qm "chore: initialise project vault" || true
		say "created: git repository"
	fi

	# Project-side pointer so `noclip` finds the vault from anywhere in the repo.
	if [ -f "$repo/roblox.json" ] && [ ! -f "$repo/.noclip" ]; then
		rel=$vault
		repo_abs=$(cd "$repo" && pwd)
		vault_abs=$(cd "$vault" && pwd)
		parent_abs=$(dirname "$repo_abs")
		case "$vault_abs" in
		"$repo_abs"/*)
			rel="../$(printf '%s' "$vault_abs" | sed "s|^$repo_abs/||")"
			;;
		"$parent_abs"/*)
			rel="../$(printf '%s' "$vault_abs" | sed "s|^$parent_abs/||")"
			;;
		esac
		{
			printf '# noclip project config — parsed by the noclip command.\n'
			printf 'vault=%s\n' "$rel"
			printf 'jobs=2\n'
			printf 'worktrees=1\n'
		} >"$repo/.noclip"
		say "created: $repo/.noclip"
	fi

	say ""
	say "vault:  $vault"
	say "repo:   $repo"
	say "next:   noclip new \"first task\" --agent scripter"
}

# ----------------------------------------------------------------------- new

cmd_new() {
	title=
	agent=scripter
	lane=files
	priority=5
	while [ $# -gt 0 ]; do
		case "$1" in
		--agent) agent=${2:-}; shift 2 ;;
		--lane) lane=${2:-}; shift 2 ;;
		--priority) priority=${2:-}; shift 2 ;;
		--*) die "new: unknown flag $1" ;;
		*) title=$1; shift ;;
		esac
	done
	[ -n "$title" ] || die "new: a title is required"

	n=1
	exists() {
		for candidate in "$1" "$2" "$3"; do
			if [ -e "$candidate" ]; then
				return 0
			fi
		done
		return 1
	}
	while exists "$BACKLOG/$(printf '%04d' "$n")"-*.md \
		"$ACTIVE/$(printf '%04d' "$n")"-*.md \
		"$DONE/$(printf '%04d' "$n")"-*.md; do
		n=$((n + 1))
	done
	slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-48)
	id=$(printf '%04d' "$n")-$slug

	cat >"$BACKLOG/$id.md" <<EOF
---
id: $id
title: $title
agent: $agent
lane: $lane
status: backlog
priority: $priority
depends:
acceptance:
---
## Intent

## Log
EOF
	say "$BACKLOG/$id.md"
}

# -------------------------------------------------------------------- status

cmd_status() {
	say "repo:   $REPO"
	say "vault:  $VAULT"
	say ""
	count() {
		set -- "$1"/*.md
		[ -e "$1" ] || { echo 0; return; }
		echo $#
	}
	say "backlog: $(count "$BACKLOG")   active: $(count "$ACTIVE")   done: $(count "$DONE")"
	if [ -d "$LOCKS/studio" ]; then
		say "studio lock: held by pid $(cat "$LOCKS/studio/pid" 2>/dev/null || echo '?')"
	else
		say "studio lock: free"
	fi
	say ""
	for f in "$ACTIVE"/*.md; do
		[ -e "$f" ] || continue
		printf '  active  %-28s %-12s %s\n' "$(task_id "$f")" "$(fm "$f" agent)" "$(fm "$f" title)"
	done
	for f in "$BACKLOG"/*.md; do
		[ -e "$f" ] || continue
		printf '  queued  %-28s %-12s %s\n' "$(task_id "$f")" "$(fm "$f" agent)" "$(fm "$f" title)"
	done
}

# ---------------------------------------------------------------------- run

run_one() {
	src=$1
	id=$(task_id "$src")
	agent=$(fm "$src" agent)
	lane=$(fm "$src" lane)
	[ -n "$id" ] || { warn "skipping note without id: $src"; return 0; }
	[ -n "$agent" ] || { warn "skipping $id: no agent"; return 0; }

	if ! command -v "$OPENCODE_BIN" >/dev/null 2>&1; then
		warn "opencode not found: $OPENCODE_BIN"
		return 1
	fi

	# Prepare the isolated checkout BEFORE claiming, so a failure here leaves the
	# note queued instead of stranding it in active/.
	workdir=$REPO
	if [ "$lane" != "studio" ] && [ "$WORKTREES" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
		mkdir -p "$WORKTREE_ROOT"
		workdir="$WORKTREE_ROOT/wt-$id"
		if [ -d "$workdir" ]; then
			:
		elif git -C "$REPO" show-ref --verify --quiet "refs/heads/noclip/$id"; then
			git -C "$REPO" worktree add -q "$workdir" "noclip/$id" || workdir=$REPO
		else
			git -C "$REPO" worktree add -q -b "noclip/$id" "$workdir" HEAD || workdir=$REPO
		fi
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		say "would run: $id ($agent, lane=$lane, dir=$workdir)"
		return 0
	fi

	# Claim by moving the note; mv fails for every racer but one.
	if [ -e "$ACTIVE/$id.md" ]; then
		return 0
	fi
	mv "$src" "$ACTIVE/$id.md" 2>/dev/null || return 0
	active="$ACTIVE/$id.md"
	set_status "$active" active

	# Any hard exit from here on (set -e, signal) must put the note back rather
	# than leave a claim nobody owns.
	finished=0
	trap 'if [ "$finished" -eq 0 ]; then set_status "$active" backlog 2>/dev/null || true; mv "$active" "$src" 2>/dev/null || true; fi' 0

	if [ "$DRY_RUN" -eq 1 ]; then
		say "would run: $id ($agent, lane=$lane)"
		mv "$active" "$src"
		set_status "$src" backlog
		finished=1
		return 0
	fi

	if [ "$lane" = "studio" ]; then
		# Studio is one mutable resource bound to the main checkout.
		if ! studio_lock; then
			warn "$id: no studio lock after ${LOCK_WAIT}s, requeueing"
			set_status "$active" backlog
			mv "$active" "$src"
			finished=1
			return 0
		fi
	fi

	log="$LOGS/$(date +%Y%m%d-%H%M%S)-$id.log"
	say "run: $id  agent=$agent  lane=$lane  dir=$workdir"

	prompt="Task note: $active
Repository: $REPO
Vault: $VAULT

Read the note first. Execute it against the acceptance criteria. Work only in
the files your role owns, append your results under '## Log' in the note, and do
not move, rename, or re-status the note — the orchestrator owns that."

	status=0
	(cd "$workdir" && "$OPENCODE_BIN" run --agent "$agent" --auto \
		--format "$FORMAT" --title "$id" "$prompt") >>"$log" 2>&1 || status=$?

	if [ "$lane" = "studio" ]; then
		studio_unlock
	fi

	if [ "$status" -eq 0 ]; then
		set_status "$active" "done"
		printf '\n## Result\n\n- exit 0 at %s\n- log: %s\n' \
			"$(date '+%Y-%m-%d %H:%M')" "$(basename "$log")" >>"$active"
		mv "$active" "$DONE/$id.md"
		finished=1
		say "done: $id"
	else
		set_status "$active" blocked
		printf '\n## Blocked\n\nThe agent exited %s. See `%s`.\n' \
			"$status" "$(basename "$log")" >>"$active"
		mv "$active" "$src"
		finished=1
		warn "blocked: $id (exit $status)"
	fi
}

cmd_run() {
	once=0
	DRY_RUN=0
	only_agent=
	while [ $# -gt 0 ]; do
		case "$1" in
		--once) once=1; shift ;;
		--dry-run) DRY_RUN=1; shift ;;
		--jobs) JOBS=${2:-}; shift 2 ;;
		--agent) only_agent=${2:-}; shift 2 ;;
		*) die "run: unknown argument $1" ;;
		esac
	done

	running=0
	for f in "$BACKLOG"/*.md; do
		[ -e "$f" ] || continue
		if [ -n "$only_agent" ] && [ "$(fm "$f" agent)" != "$only_agent" ]; then
			continue
		fi
		run_one "$f" &
		running=$((running + 1))
		if [ "$once" -eq 1 ]; then
			wait || true
			return 0
		fi
		if [ "$running" -ge "$JOBS" ]; then
			wait || true
			running=0
		fi
	done
	wait || true
}

# -------------------------------------------------------------------- merge

cmd_merge() {
	[ $# -eq 1 ] || die "merge: task id required"
	id=$1
	branch="noclip/$id"
	git -C "$REPO" show-ref --verify --quiet "refs/heads/$branch" ||
		die "merge: no branch $branch"
	[ -z "$(git -C "$REPO" status --porcelain)" ] ||
		die "merge: working tree is dirty; commit or stash first"
	git -C "$REPO" merge --no-ff "$branch" -m "merge: $id"
	wt="$WORKTREE_ROOT/wt-$id"
	[ -d "$wt" ] && git -C "$REPO" worktree remove --force "$wt" || true
	git -C "$REPO" branch -d "$branch" || true
	say "merged: $id"
}

# ------------------------------------------------------------------- doctor

cmd_doctor() {
	rc=0
	check() {
		name=$1
		shift
		if "$@" >/dev/null 2>&1; then
			printf '  ok    %s\n' "$name"
		else
			printf '  FAIL  %s\n' "$name"
			rc=1
		fi
	}
	say "noclip $VERSION"
	say ""
	check "opencode ($OPENCODE_BIN)" command -v "$OPENCODE_BIN"
	check "git" command -v git
	check "rojo" command -v rojo
	check "devenv" command -v devenv
	check "roblox-studio-mcp" command -v roblox-studio-mcp
	check "vault is a git repository" test -d "$VAULT/.git"
	check "repo is a git repository" test -d "$REPO/.git"
	check "vault AGENTS.md" test -f "$VAULT/AGENTS.md"
	check "task template" test -f "$VAULT/templates/task.md"

	if [ -d "$LOCKS/studio" ]; then
		pid=$(cat "$LOCKS/studio/pid" 2>/dev/null || echo '')
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			printf '  ok    studio lock held by live pid %s\n' "$pid"
		else
			printf '  WARN  stale studio lock (pid %s); remove %s\n' "${pid:-?}" "$LOCKS/studio"
		fi
	fi

	if [ -f "$VAULT/AGENTS.md" ]; then
		for role in librarian designer scripter asset-smith audio qa builder lore-keeper; do
			if [ -f "$HOME/.config/opencode/agents/$role.md" ]; then
				printf '  ok    agent %s\n' "$role"
			else
				printf '  FAIL  agent %s missing from ~/.config/opencode/agents\n' "$role"
				rc=1
			fi
		done
	fi

	wt=$(git -C "$REPO" worktree list 2>/dev/null | wc -l | tr -d ' ')
	say ""
	say "worktrees: $wt   jobs: $JOBS   worktree mode: $WORKTREES   format: $FORMAT"
	return "$rc"
}

# --------------------------------------------------------------------- help

cmd_help() {
	cat <<EOF
noclip $VERSION — vault-driven agent dispatcher for a Rojo Roblox project

  noclip init [--vault DIR] [--repo DIR]   scaffold an idempotent vault + .noclip
  noclip new "Title" [--agent ROLE] [--lane files|studio] [--priority N]
  noclip status                            queue board, studio lock state
  noclip run [--once] [--jobs N] [--agent ROLE] [--dry-run]
  noclip merge TASK_ID                     merge noclip/TASK_ID into the branch
  noclip doctor                            verify toolchain, vault, agents, lock

Config is read from the nearest .noclip walking up from the cwd:

  vault=../noclip-vault      # relative to the repo root
  jobs=2                     # files-lane concurrency
  worktrees=1                # isolate each files-lane task in a git worktree
  opencode=opencode          # binary to dispatch
  format=default             # default | json
  lock_wait=600              # seconds to wait for the studio lock

Environment overrides: NOCLIP_VAULT NOCLIP_REPO NOCLIP_JOBS NOCLIP_WORKTREES
NOCLIP_OPENCODE NOCLIP_FORMAT NOCLIP_LOCK_WAIT
EOF
}

# --------------------------------------------------------------------- main

[ $# -ge 1 ] || { cmd_help; exit 2; }
command=$1
shift

case "$command" in
init) cmd_init "$@" ;;
help | -h | --help) cmd_help ;;
*)
	load_config
	case "$command" in
	new) cmd_new "$@" ;;
	status) cmd_status ;;
	run) cmd_run "$@" ;;
	merge) cmd_merge "$@" ;;
	doctor) cmd_doctor ;;
	*) die "unknown command: $command (try 'noclip help')" ;;
	esac
	;;
esac
