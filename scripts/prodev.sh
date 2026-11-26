#!/usr/bin/env bash
# prodev — pro-dev orchestration CLI.
#
# The single entry point shared by the human, the orchestrator agent and the
# worker agents. It owns the vault pointer, the task queue, the two worker
# slots, the GitHub issue format, and the hooks that Claude Code calls.
#
# Usage: prodev <command> [args]   (see `prodev help`)
set -euo pipefail

VERSION="0.1.0"
TEMPLATES="${PRODEV_TEMPLATES:-}"
SLOTS_DEFAULT=2

say() { printf '%s\n' "$*"; }
warn() { printf 'prodev: %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

help() {
	cat <<'EOF'
prodev — plan, file, dispatch, verify

  init [--vault PATH] [--slots N]     write .prodev, create + git-init the vault
  vault init|link <path>|status       manage the vault location
  status [--line|--quiet]             vault, task counts, live leases
  context [--max-chars N]             rehydration pack for a fresh/compacted session
  task new --title T [options]        create a backlog note
  task claim <id>                     take the lease for a task
  task done <id> [--report-file F]     move to done, release the lease
  dispatch [--tool opencode|claude] [--slots N] [--dry-run]
  issue new --type T --title T [--task id]
  issue close <number> [--task id] [--summary S]
  issue check                         list open issues
  log --role ROLE --task ID --message M
  claude [args...]                    Claude Code in pro-dev mode (used by ccp)
  hook session-start|post-compact|guard-spawn|guard-bash
  doctor

Environment:
  PRODEV_VAULT   override the vault path for one invocation
  PRODEV_MODE=1  set by the pro-dev launchers; enables the hooks
  PRODEV_WORKER=1 set for a headless worker session

Files:
  <repo>/.prodev         committed: vault=<relative path>, slots=<n>
  <repo>/.prodev.local   ignored: per-machine overrides (vault=, slots=)
EOF
}

# ---------------------------------------------------------------- discovery

find_up() {
	local dir
	dir=$(pwd)
	while :; do
		if [ -e "$dir/$1" ]; then
			printf '%s\n' "$dir"
			return 0
		fi
		[ "$dir" = "/" ] && return 1
		dir=$(dirname "$dir")
	done
}

repo_root() {
	local d
	if d=$(find_up .prodev); then printf '%s\n' "$d"; return 0; fi
	if d=$(find_up .git); then printf '%s\n' "$d"; return 0; fi
	return 1
}

# Worktrees live inside the repo, so a relative vault path must resolve from the
# main checkout, never from the worktree root.
main_root() {
	local common
	common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
	dirname "$common"
}

conf_get() {
	[ -f "$1" ] || return 1
	sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" | sed -n '1p'
}

conf_set() {
	local file=$1 key=$2 value=$3
	if [ -f "$file" ] && grep -qE "^[[:space:]]*$key[[:space:]]*=" "$file"; then
		sed -i "s|^[[:space:]]*$key[[:space:]]*=.*|$key=$value|" "$file"
	else
		printf '%s=%s\n' "$key" "$value" >>"$file"
	fi
}

vault_from() {
	local repo=$1 value="" root
	value=$(conf_get "$repo/.prodev.local" vault 2>/dev/null || true)
	[ -n "$value" ] || value=$(conf_get "$repo/.prodev" vault 2>/dev/null || true)
	[ -n "$value" ] || return 1
	case $value in
	/*) printf '%s\n' "$value" ;;
	*)
		root=$(main_root 2>/dev/null || printf '%s' "$repo")
		printf '%s\n' "$root/$value"
		;;
	esac
}

resolve_vault() {
	local repo=$1
	if [ -n "${PRODEV_VAULT:-}" ]; then
		case ${PRODEV_VAULT} in
		/*) printf '%s\n' "$PRODEV_VAULT" ;;
		*) printf '%s\n' "$(main_root 2>/dev/null || printf '%s' "$repo")/${PRODEV_VAULT}" ;;
		esac
		return 0
	fi
	vault_from "$repo"
}

require_vault() {
	local vault
	vault=$(resolve_vault "$1") || die "no vault configured for $1 (run: prodev init)"
	[ -d "$vault" ] || die "vault directory is missing: $vault (run: prodev init)"
	printf '%s\n' "$vault"
}

set_vault() {
	VAULT=$1
	BRIEF="$VAULT/00-brief"
	KNOW="$VAULT/10-knowledge"
	PLANS="$VAULT/20-plans"
	BACKLOG="$VAULT/40-tasks/backlog"
	ACTIVE="$VAULT/40-tasks/active"
	DONE="$VAULT/40-tasks/done"
	LOGS="$VAULT/50-log"
	LOGS_ORCH="$LOGS/orchestrator"
	LOGS_WORK="$LOGS/workers"
	DECISIONS="$VAULT/90-decisions"
	LOCKS="$VAULT/.locks"
}

in_mode() { [ "${PRODEV_MODE:-0}" = "1" ]; }
is_worker() { [ "${PRODEV_WORKER:-0}" = "1" ]; }

# ---------------------------------------------------------------- frontmatter

# fm <file> <key>: first value of a key in the leading --- block.
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

set_fm() {
	local file=$1 key=$2 value=$3
	if grep -qE "^$key:" "$file"; then
		sed -i "s|^$key:.*|$key: $value|" "$file"
	else
		sed -i "1a $key: $value" "$file"
	fi
}

slugify() {
	printf '%s' "$1" |
		tr '[:upper:]' '[:lower:]' |
		sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//' |
		cut -c1-48
}

next_id() {
	local max
	max=$(find "$BACKLOG" "$ACTIVE" "$DONE" -maxdepth 1 -name '*.md' 2>/dev/null |
		sed -n 's|.*/\([0-9][0-9]*\)-.*|\1|p' | sort -n | tail -1)
	printf '%04d\n' $((${max:-0} + 1))
}

task_note() {
	local id=$1 dir
	for dir in "$ACTIVE" "$BACKLOG" "$DONE"; do
		[ -e "$dir/$id.md" ] && { printf '%s\n' "$dir/$id.md"; return 0; }
	done
	# A note may have a slug suffix; fall back to a prefix match.
	find "$ACTIVE" "$BACKLOG" "$DONE" -maxdepth 1 -name "$id-*.md" 2>/dev/null | head -1
}

render() {
	local file=$1 out
	shift
	out=$(cat "$file")
	for pair in "$@"; do
		out=$(printf '%s' "$out" | awk -v k="{{${pair%%=*}}}" -v v="${pair#*=}" '{gsub(k, v)}1')
	done
	printf '%s\n' "$out"
}

vault_commit() {
	local message=$1
	if [ -d "$VAULT/.git" ]; then
		git -C "$VAULT" add -A >/dev/null 2>&1 || true
		git -C "$VAULT" commit -qm "$message" >/dev/null 2>&1 || true
	fi
}

lock_count() {
	find "$LOCKS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------- init / vault

cmd_init() {
	local vault="" slots=""
	while [ $# -gt 0 ]; do
		case $1 in
		--vault) vault=${2:-}; shift 2 ;;
		--slots) slots=${2:-}; shift 2 ;;
		*) die "init: unknown argument $1" ;;
		esac
	done

	local repo
	repo=$(repo_root) || repo=$(pwd)
	[ -d "$repo/.git" ] || warn "$repo is not a git repository (agents will refuse to dispatch)"

	if [ ! -f "$repo/.prodev" ]; then
		{
			printf 'vault=.prodev-vault\n'
			printf 'slots=%s\n' "${slots:-$SLOTS_DEFAULT}"
		} >"$repo/.prodev"
		say "created: $repo/.prodev"
	else
		say "kept:    $repo/.prodev"
	fi
	[ -n "$slots" ] && conf_set "$repo/.prodev" slots "$slots"
	[ -n "$vault" ] && conf_set "$repo/.prodev" vault "$vault"

	local ignore="$repo/.gitignore"
	touch "$ignore"
	local entry
	for entry in ".prodev-vault/" ".prodev.local" ".prodev/worktrees/" ".DS_Store"; do
		grep -qxF "$entry" "$ignore" || printf '%s\n' "$entry" >>"$ignore"
	done

	local target
	target=$(resolve_vault "$repo") || die "cannot resolve the vault path"
	mkdir -p "$target"/{00-brief,10-knowledge,20-plans,40-tasks/{backlog,active,done},50-log/{orchestrator,workers},90-decisions,templates,.locks}

	[ -f "$target/README.md" ] || cat >"$target/README.md" <<'EOF'
---
tags: [moc]
---
# Project vault

Shared memory for this repository's pro-dev workflow.

| Folder | Holds |
|---|---|
| `00-brief/` | what the project is, constraints, stack |
| `10-knowledge/` | linked notes; `graph.md` is the entry point |
| `20-plans/` | one plan per task |
| `40-tasks/` | backlog → active → done |
| `50-log/` | orchestrator and worker logs |
| `90-decisions/` | ADRs |
EOF

	[ -f "$target/10-knowledge/graph.md" ] || cat >"$target/10-knowledge/graph.md" <<'EOF'
---
tags: [moc, graph]
---
# Knowledge graph

Add one line per durable fact, linking the note that owns it.

- [[architecture]] — how the system fits together
- [[gotchas]] — things that have bitten us before
- [[commands]] — build, test, and release commands
EOF

	for note in architecture gotchas commands; do
		[ -f "$target/10-knowledge/$note.md" ] ||
			printf -- '---\ntags: [knowledge]\n---\n# %s\n\n' "$note" >"$target/10-knowledge/$note.md"
	done

	[ -f "$target/00-brief/project.md" ] || cat >"$target/00-brief/project.md" <<'EOF'
---
tags: [brief]
---
# Project brief

## What it is

## Constraints

## How it is verified
EOF

	printf '.locks/\n.DS_Store\n.obsidian/workspace*\n' >"$target/.gitignore"

	if [ ! -d "$target/.git" ]; then
		git -C "$target" init -q
		git -C "$target" add -A
		git -C "$target" commit -qm "chore: initialise pro-dev vault" || true
		say "created: $target (git repository)"
	else
		say "kept:    $target"
	fi

	say ""
	say "vault:   $target"
	say "repo:    $repo"
	say "next:    prodev doctor && ccp"
}

cmd_vault() {
	local action=${1:-status}
	shift || true
	local repo vault
	repo=$(repo_root) || die "not inside a project"
	case $action in
	init)
		cmd_init --vault "${1:-}"
		;;
	link)
		[ -n "${1:-}" ] || die "vault link: missing path"
		[ -d "$1" ] || die "vault link: not a directory: $1"
		conf_set "$repo/.prodev.local" vault "$(cd "$1" && pwd)"
		say "linked: $(cd "$1" && pwd)"
		;;
	status)
		vault=$(resolve_vault "$repo") || die "no vault configured"
		say "vault: $vault"
		[ -d "$vault" ] && say "state: ok" || say "state: missing"
		;;
	*) die "vault: unknown action $action" ;;
	esac
}

# ---------------------------------------------------------------- status

cmd_status() {
	local line=0 quiet=0
	while [ $# -gt 0 ]; do
		case $1 in
		--line) line=1; shift ;;
		--quiet) quiet=1; shift ;;
		*) die "status: unknown argument $1" ;;
		esac
	done

	if [ "$quiet" -eq 1 ]; then
		in_mode && exit 0
		exit 1
	fi

	local mode repo vault name backlog=0 active=0 done=0 workers=0
	if in_mode; then mode="pro"; else mode="off"; fi

	repo=$(repo_root 2>/dev/null || true)
	vault=""
	name="-"
	if [ -n "$repo" ]; then
		vault=$(resolve_vault "$repo" 2>/dev/null || true)
	fi
	if [ -n "$vault" ] && [ -d "$vault" ]; then
		set_vault "$vault"
		name=$(basename "${repo:-$vault}")
		backlog=$(find "$BACKLOG" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
		active=$(find "$ACTIVE" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
		done=$(find "$DONE" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
		workers=$(lock_count)
	else
		name="none"
	fi

	if [ "$line" -eq 1 ]; then
		printf '[%s] %s · vault:%s · workers %s/%s · tasks %s/%s\n' \
			"$mode" "$name" "$(basename "${vault:-none}")" "$workers" "$SLOTS_DEFAULT" "$active" "$backlog"
		return 0
	fi

	say "mode:    $mode"
	say "repo:    ${repo:-not in a project}"
	say "vault:   ${vault:-none}"
	say "tasks:   backlog $backlog · active $active · done $done"
	say "workers: $workers/$SLOTS_DEFAULT"
	if [ "$workers" -gt 0 ] && [ -d "$LOCKS" ]; then
		find "$LOCKS" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/  lease: /'
	fi
}

# ---------------------------------------------------------------- context

cmd_context() {
	local max=9000
	while [ $# -gt 0 ]; do
		case $1 in
		--max-chars) max=${2:-9000}; shift 2 ;;
		*) die "context: unknown argument $1" ;;
		esac
	done
	local repo vault
	repo=$(repo_root) || die "not inside a project"
	vault=$(resolve_vault "$repo") || die "no vault configured"
	set_vault "$vault"

	{
		printf '# pro-dev context\n\n'
		printf -- '- mode: %s\n' "$(in_mode && echo pro || echo off)"
		printf -- '- repo: %s\n' "$repo"
		printf -- '- vault: %s\n\n' "$vault"

		if [ -f "$BRIEF/project.md" ]; then
			printf '## Brief\n\n'
			cat "$BRIEF/project.md"
			printf '\n'
		fi
		if [ -f "$KNOW/graph.md" ]; then
			printf '## Knowledge map\n\n'
			sed -n '1,120p' "$KNOW/graph.md"
			printf '\n'
		fi

		printf '## Active plans\n\n'
		local plan found=0
		for plan in "$PLANS"/*.md; do
			[ -e "$plan" ] || continue
			found=1
			printf '### %s\n\n' "$(basename "$plan")"
			sed -n '1,40p' "$plan"
			printf '\n'
		done
		[ "$found" -eq 1 ] || printf 'none\n\n'

		printf '## Task queue\n\n'
		local note
		for note in "$ACTIVE"/*.md "$BACKLOG"/*.md; do
			[ -e "$note" ] || continue
			printf -- '- %s [%s] %s (github: %s)\n' \
				"$(fm "$note" id)" "$(fm "$note" status)" "$(fm "$note" title)" "$(fm "$note" github)"
		done
		printf '\n'

		printf '## Worker leases\n\n'
		if [ "$(lock_count)" -eq 0 ]; then
			printf 'none\n\n'
		else
			find "$LOCKS" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/- /'
			printf '\n'
		fi

		printf '## Open issues\n\n'
		if command -v gh >/dev/null 2>&1; then
			(cd "$repo" && gh issue list --state open --limit 15 2>/dev/null) ||
				printf 'gh not authenticated or offline (run: gh auth login)\n'
		else
			printf 'gh not installed\n'
		fi
		printf '\n'

		printf '## Recent orchestrator log\n\n'
		local log
		log=$(find "$LOGS_ORCH" -maxdepth 1 -name '*.md' 2>/dev/null | sort | tail -1)
		if [ -n "$log" ]; then
			sed -n '1,60p' "$log"
		else
			printf 'none\n'
		fi
	} | head -c "$max"
	printf '\n'
}

# ---------------------------------------------------------------- tasks

cmd_task() {
	local action=${1:-}
	shift || true
	local repo vault
	repo=$(repo_root) || die "not inside a project"
	vault=$(require_vault "$repo")
	set_vault "$vault"

	case $action in
	new)
		local title="" tier="work" files="" depends="" goal="" acceptance=""
		while [ $# -gt 0 ]; do
			case $1 in
			--title) title=${2:-}; shift 2 ;;
			--tier) tier=${2:-}; shift 2 ;;
			--files) files=${2:-}; shift 2 ;;
			--depends) depends=${2:-}; shift 2 ;;
			--goal) goal=${2:-}; shift 2 ;;
			--acceptance) acceptance=${2:-}; shift 2 ;;
			*) die "task new: unknown argument $1" ;;
			esac
		done
		[ -n "$title" ] || die "task new: --title is required"
		[ "$tier" = "work" ] || [ "$tier" = "lite" ] || die "task new: --tier must be work or lite"
		local id slug note
		id=$(next_id)
		slug=$(slugify "$title")
		note="$BACKLOG/$id-$slug.md"
		render "$TEMPLATES/task.md" \
			"ID=$id" "TITLE=$title" "TIER=$tier" "FILES=$files" \
			"DEPENDS=$depends" "GITHUB=" "DATE=$(date +%Y-%m-%d)" \
			"GOAL=$goal" "ACCEPTANCE=$acceptance" >"$note"
		vault_commit "task: add $id"
		say "$note"
		;;
	claim)
		local id=${1:-}
		[ -n "$id" ] || die "task claim: missing id"
		mkdir "$LOCKS/$id" 2>/dev/null || die "task $id is already claimed"
		local note
		note=$(task_note "$id") || die "task $id not found"
		case $note in
		"$BACKLOG"/*)
			mv "$note" "$ACTIVE/$(basename "$note")"
			note="$ACTIVE/$(basename "$note")"
			set_fm "$note" status active
			;;
		esac
		vault_commit "task: claim $id"
		say "$note"
		;;
	done)
		local id=${1:-} report=""
		shift || true
		while [ $# -gt 0 ]; do
			case $1 in
			--report-file)
				if [ "${2:-}" = "-" ]; then report=$(cat); else report=$(cat "${2:-}"); fi
				shift 2
				;;
			*) die "task done: unknown argument $1" ;;
			esac
		done
		[ -n "$id" ] || die "task done: missing id"
		local note
		note=$(task_note "$id") || die "task $id not found"
		[ -n "$report" ] && printf '\n## Result\n\n%s\n' "$report" >>"$note"
		set_fm "$note" status done
		printf '\n- done %s\n' "$(date '+%Y-%m-%d %H:%M')" >>"$note"
		mv "$note" "$DONE/$(basename "$note")" 2>/dev/null || true
		rmdir "$LOCKS/$id" 2>/dev/null || true
		vault_commit "task: done $id"
		say "done: $id"
		;;
	*) die "task: unknown action ${action:-}" ;;
	esac
}

# ---------------------------------------------------------------- dispatch

paths_overlap() {
	local a=$1 b=$2 x y
	for x in ${a//,/ }; do
		for y in ${b//,/ }; do
			[ "$x" = "$y" ] && return 0
		done
	done
	return 1
}

run_worker() {
	local note=$1 id=$2 tier=$3 tool=$4 repo=$5 log=$6
	local agent="pro-worker"
	[ "$tier" = "lite" ] && agent="pro-worker-lite"
	[ "$tool" = "claude" ] && [ "$tier" = "lite" ] && agent="pro-worker-lite"

	local wt="$repo/.prodev/worktrees/wt-$id"
	local branch="prodev/$id"
	mkdir -p "$repo/.prodev/worktrees"
	if [ ! -d "$wt" ]; then
		if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
			git -C "$repo" worktree add -q "$wt" "$branch" || wt=$repo
		else
			git -C "$repo" worktree add -q -b "$branch" "$wt" HEAD || wt=$repo
		fi
	fi

	local prompt
	prompt="You are pro-worker. Implement exactly one task and report.
Task note: $note
Branch: $branch (already checked out in this worktree)
Commit your work on this branch. Do not push, do not merge, do not edit
.prodev-vault/**, and do not touch files outside the task's files: list.
Run the project checks, then print a short report: changed, verified,
not verified, follow-ups."

	printf '# worker log — %s\n\n- tool: %s\n- agent: %s\n- worktree: %s\n\n' \
		"$id" "$tool" "$agent" "$wt" >"$log"

	case $tool in
	opencode)
		(cd "$wt" && opencode --standalone run --agent "$agent" --title "$id" "$prompt") >>"$log" 2>&1
		;;
	claude)
		(cd "$wt" && PRODEV_WORKER=1 claude -p --agent "$agent" \
			--settings "$HOME/.claude/prodev/worker.settings.json" "$prompt") >>"$log" 2>&1
		;;
	*) die "dispatch: unknown tool $tool" ;;
	esac
}

cmd_dispatch() {
	local tool="opencode" slots="$SLOTS_DEFAULT" dry=0
	while [ $# -gt 0 ]; do
		case $1 in
		--tool) tool=${2:-}; shift 2 ;;
		--slots) slots=${2:-}; shift 2 ;;
		--dry-run) dry=1; shift ;;
		*) die "dispatch: unknown argument $1" ;;
		esac
	done

	local repo vault
	repo=$(repo_root) || die "not inside a project"
	vault=$(require_vault "$repo")
	set_vault "$vault"

	local -a picked=() ids=() sets=()
	local note id github files ok previous
	while IFS= read -r note; do
		[ -e "$note" ] || continue
		id=$(fm "$note" id)
		github=$(fm "$note" github)
		files=$(fm "$note" files)
		[ -n "$id" ] || continue
		if [ -z "$github" ]; then
			warn "skip $id: no GitHub issue (issue-first rule)"
			continue
		fi
		if [ -d "$LOCKS/$id" ]; then
			warn "skip $id: already claimed"
			continue
		fi
		ok=1
		for previous in ${sets[@]+"${sets[@]}"}; do
			if paths_overlap "$previous" "$files"; then ok=0; break; fi
		done
		if [ "$ok" -eq 0 ]; then
			warn "skip $id: files overlap an already-selected task"
			continue
		fi
		picked+=("$note")
		ids+=("$id")
		sets+=("$files")
		[ ${#picked[@]} -ge "$slots" ] && break
	done < <(find "$BACKLOG" -maxdepth 1 -name '*.md' 2>/dev/null | sort)

	if [ ${#picked[@]} -eq 0 ]; then
		say "nothing to dispatch"
		return 0
	fi

	if [ "$dry" -eq 1 ]; then
		local i
		for i in "${!picked[@]}"; do
			say "would run: ${ids[$i]} (tier=$(fm "${picked[$i]}" tier), files=${sets[$i]})"
		done
		return 0
	fi

	# Claim every selected task before spawning, so a failure to claim shrinks
	# the batch instead of racing another dispatcher.
	local -a run_notes=() run_ids=() run_tiers=()
	local i
	for i in "${!picked[@]}"; do
		if mkdir "$LOCKS/${ids[$i]}" 2>/dev/null; then
			mv "${picked[$i]}" "$ACTIVE/$(basename "${picked[$i]}")"
			set_fm "$ACTIVE/$(basename "${picked[$i]}")" status active
			run_notes+=("$ACTIVE/$(basename "${picked[$i]}")")
			run_ids+=("${ids[$i]}")
			run_tiers+=("$(fm "${picked[$i]}" tier)")
		else
			warn "skip ${ids[$i]}: lost the claim race"
		fi
	done
	vault_commit "task: dispatch ${run_ids[*]:-}"

	local -a pids=() run_logs=()
	for i in "${!run_ids[@]}"; do
		run_logs+=("$LOGS_WORK/$(date +%Y%m%d-%H%M%S)-${run_ids[$i]}.md")
		run_worker "${run_notes[$i]}" "${run_ids[$i]}" "${run_tiers[$i]}" "$tool" "$repo" \
			"${run_logs[$i]}" &
		pids+=($!)
	done

	local failed=0
	for i in "${!pids[@]}"; do
		if wait "${pids[$i]}"; then
			set_fm "${run_notes[$i]}" status review
			say "ok:   ${run_ids[$i]} (log: ${run_logs[$i]})"
		else
			set_fm "${run_notes[$i]}" status blocked
			printf '\n## Blocked\n\nWorker exited non-zero; see %s.\n' \
				"${run_logs[$i]}" >>"${run_notes[$i]}"
			failed=$((failed + 1))
			say "fail: ${run_ids[$i]} (log: ${run_logs[$i]})"
		fi
		rmdir "$LOCKS/${run_ids[$i]}" 2>/dev/null || true
	done
	vault_commit "task: dispatch results"
	[ "$failed" -eq 0 ] || warn "$failed worker(s) failed; tasks stay active with status blocked"
}

# ---------------------------------------------------------------- issues

cmd_issue() {
	local action=${1:-}
	shift || true
	local repo vault
	repo=$(repo_root) || die "not inside a project"
	command -v gh >/dev/null 2>&1 || die "gh is not installed"
	vault=$(resolve_vault "$repo" 2>/dev/null || true)
	[ -n "$vault" ] && [ -d "$vault" ] && set_vault "$vault"

	case $action in
	new)
		local type="feature" title="" task="" context="" plan="" files="" acceptance=""
		while [ $# -gt 0 ]; do
			case $1 in
			--type) type=${2:-}; shift 2 ;;
			--title) title=${2:-}; shift 2 ;;
			--task) task=${2:-}; shift 2 ;;
			--context) context=${2:-}; shift 2 ;;
			--plan) plan=${2:-}; shift 2 ;;
			--files) files=${2:-}; shift 2 ;;
			--acceptance) acceptance=${2:-}; shift 2 ;;
			*) die "issue new: unknown argument $1" ;;
			esac
		done
		[ -n "$title" ] || die "issue new: --title is required"
		local body
		body=$(mktemp)
		render "$TEMPLATES/issue.md" \
			"CONTEXT=${context:-TBD}" "PLAN=${plan:-TBD}" "FILES=${files:-TBD}" \
			"ACCEPTANCE=${acceptance:-TBD}" "TASK=${task:-none}" >"$body"
		local url
		if ! url=$(cd "$repo" && gh issue create --title "$title" --label "$type" --body-file "$body" 2>&1); then
			warn "label '$type' is not available in this repository; creating without it"
			url=$(cd "$repo" && gh issue create --title "$title" --body-file "$body" 2>&1) ||
				die "gh issue create failed: $url"
		fi
		rm -f "$body"
		local number
		number=$(printf '%s' "$url" | sed -n 's|.*/issues/\([0-9][0-9]*\).*|\1|p')
		say "issue: $number"
		say "$url"
		if [ -n "$task" ] && [ -n "$number" ] && [ -n "$vault" ]; then
			local note
			note=$(task_note "$task") || true
			if [ -n "$note" ] && [ -e "$note" ]; then
				set_fm "$note" github "$number"
				vault_commit "issue: link $task -> #$number"
			fi
		fi
		;;
	close)
		local number=${1:-} task="" summary=""
		shift || true
		while [ $# -gt 0 ]; do
			case $1 in
			--task) task=${2:-}; shift 2 ;;
			--summary) summary=${2:-}; shift 2 ;;
			*) die "issue close: unknown argument $1" ;;
			esac
		done
		[ -n "$number" ] || die "issue close: missing issue number"
		(cd "$repo" && gh issue close "$number" --comment "Closed via pro-dev.

${summary:-No summary provided.}") || die "gh issue close failed"
		say "closed: $number"
		;;
	check)
		(cd "$repo" && gh issue list --state open --limit 30)
		;;
	*) die "issue: unknown action ${action:-}" ;;
	esac
}

# ---------------------------------------------------------------- log

cmd_log() {
	local role="orchestrator" task="none" message=""
	while [ $# -gt 0 ]; do
		case $1 in
		--role) role=${2:-}; shift 2 ;;
		--task) task=${2:-}; shift 2 ;;
		--message) message=${2:-}; shift 2 ;;
		*) die "log: unknown argument $1" ;;
		esac
	done
	local repo vault
	repo=$(repo_root) || die "not inside a project"
	vault=$(require_vault "$repo")
	set_vault "$vault"
	local dir
	case $role in
	orchestrator) dir="$LOGS_ORCH" ;;
	worker) dir="$LOGS_WORK" ;;
	*) die "log: --role must be orchestrator or worker" ;;
	esac
	local file="$dir/$(date +%Y%m%d-%H%M%S)-$task.md"
	render "$TEMPLATES/log.md" "TASK=$task" "ROLE=$role" \
		"DATE=$(date '+%Y-%m-%d %H:%M')" "MESSAGE=${message}" >"$file"
	vault_commit "log: $role $task"
	say "$file"
}

# ---------------------------------------------------------------- claude

cmd_claude() {
	local repo vault
	repo=$(repo_root) || die "not inside a project (run: prodev init)"
	vault=$(require_vault "$repo")
	PRODEV_MODE=1
	PRODEV_VAULT="$vault"
	export PRODEV_MODE PRODEV_VAULT
	exec claude \
		--settings "$HOME/.claude/prodev/settings.json" \
		--agent pro-dev \
		"$@"
}

# ---------------------------------------------------------------- hooks

hook_session_start() {
	in_mode || return 0
	local repo
	repo=$(repo_root 2>/dev/null) || return 0
	[ -n "$repo" ] || return 0
	cmd_context --max-chars 9000 || return 0
}

hook_post_compact() {
	in_mode || return 0
	local repo vault
	repo=$(repo_root 2>/dev/null) || return 0
	vault=$(resolve_vault "$repo" 2>/dev/null) || return 0
	[ -n "$vault" ] && [ -d "$vault" ] || return 0
	set_vault "$vault"
	printf '\n## Compaction\n\n- compacted at %s\n' "$(date '+%Y-%m-%d %H:%M')" \
		>>"$LOGS_ORCH/$(date +%Y%m%d)-session.md"
}

hook_guard_spawn() {
	in_mode || return 0
	local payload
	payload=$(cat)
	local repo vault
	repo=$(repo_root 2>/dev/null) || return 0
	vault=$(resolve_vault "$repo" 2>/dev/null) || return 0
	[ -n "$vault" ] && [ -d "$vault" ] || return 0
	set_vault "$vault"

	local active
	active=$(lock_count)
	if [ "$active" -ge "$SLOTS_DEFAULT" ]; then
		local ids
		ids=$(find "$LOCKS" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | paste -sd, -)
		printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s worker slots are already in use (%s). Wait for a report, or finish one task before spawning another."}}\n' \
			"$SLOTS_DEFAULT" "$ids"
	fi
	: "$payload"
}

hook_guard_bash() {
	in_mode || return 0
	is_worker && return 0
	local payload command
	payload=$(cat)
	command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
	[ -n "$command" ] || return 0

	local reason=""
	case $command in
	*git\ push*) reason="git push is forbidden in pro-dev; the human pushes" ;;
	*git\ reset\ --hard*) reason="git reset --hard is forbidden in pro-dev" ;;
	*git\ clean\ -fdx*) reason="git clean -fdx is forbidden in pro-dev" ;;
	*rm\ -rf*) reason="rm -rf is forbidden in pro-dev" ;;
	*git\ commit*) reason="the orchestrator does not commit; a worker commits on its branch" ;;
	esac

	[ -n "$reason" ] || return 0
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
}

# ---------------------------------------------------------------- doctor

cmd_doctor() {
	local rc=0
	check() {
		local label=$1
		shift
		if "$@" >/dev/null 2>&1; then
			say "ok    $label"
		else
			say "FAIL  $label"
			rc=1
		fi
	}
	local repo vault
	repo=$(repo_root 2>/dev/null) || repo=""
	if [ -n "$repo" ]; then
		say "ok    project: $repo"
	else
		say "FAIL  not inside a project (run: prodev init)"
		rc=1
	fi
	if [ -n "$repo" ] && [ -f "$repo/.prodev" ]; then
		say "ok    pointer: $repo/.prodev"
	else
		say "FAIL  missing .prodev"
		rc=1
	fi
	vault=$(resolve_vault "${repo:-.}" 2>/dev/null || true)
	if [ -n "$vault" ] && [ -d "$vault/.git" ]; then
		say "ok    vault: $vault"
	else
		say "FAIL  vault missing or not a git repository: ${vault:-unresolved}"
		rc=1
	fi
	check "git" git --version
	check "gh" gh --version
	check "gh auth" gh auth status
	check "jq" jq --version
	check "opencode" opencode --version
	check "claude" claude --version
	[ -d "$HOME/.claude/prodev" ] && say "ok    claude pro overlay" || say "warn  claude pro overlay not deployed"
	return "$rc"
}

# ---------------------------------------------------------------- main

command=${1:-help}
shift || true
case $command in
init) cmd_init "$@" ;;
vault) cmd_vault "$@" ;;
status) cmd_status "$@" ;;
context) cmd_context "$@" ;;
task) cmd_task "$@" ;;
dispatch) cmd_dispatch "$@" ;;
issue) cmd_issue "$@" ;;
log) cmd_log "$@" ;;
claude) cmd_claude "$@" ;;
doctor) cmd_doctor "$@" ;;
hook)
	hook_action=${1:-}
	shift || true
	case $hook_action in
	session-start) hook_session_start ;;
	post-compact) hook_post_compact ;;
	guard-spawn) hook_guard_spawn ;;
	guard-bash) hook_guard_bash ;;
	*) die "hook: unknown hook $hook_action" ;;
	esac
	;;
version | -v | --version) say "$VERSION" ;;
help | -h | --help) help ;;
*) die "unknown command: $command (try: prodev help)" ;;
esac
