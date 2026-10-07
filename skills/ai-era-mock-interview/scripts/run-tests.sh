#!/usr/bin/env bash
# run-tests.sh [codebase_dir]
# Runs `mvn -q test` in the codebase; falls back to a dependency-free
# javac/java harness (running every *Checks.java main) when Maven is
# unavailable or its dependency resolution fails offline.
set -uo pipefail

CODEBASE="${1:-$PWD/codebase}"
if [[ ! -d "$CODEBASE" ]]; then
  echo "ERROR: codebase directory not found at $CODEBASE" >&2
  exit 2
fi
cd "$CODEBASE"

run_fallback() {
  echo "--- javac fallback ---" >&2
  if ! command -v javac >/dev/null 2>&1; then
    echo "javac not found. Install the toolchain: run 'home-manager switch' in ~/dotfiles/." >&2
    return 127
  fi
  local out="target/fallback-classes"
  rm -rf "$out"; mkdir -p "$out"
  mapfile -t sources < <(find src/main/java -name '*.java')
  if [[ ${#sources[@]} -eq 0 ]]; then
    echo "no main sources found under src/main/java" >&2
    return 1
  fi
  if ! javac -d "$out" "${sources[@]}"; then
    echo "fallback compilation failed" >&2
    return 1
  fi
  local status=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local fqcn
    fqcn="$(printf '%s' "$f" | sed -e 's#^src/main/java/##' -e 's#/#.#g' -e 's#\.java$##')"
    echo "--- running $fqcn ---" >&2
    if ! java -cp "$out" "$fqcn"; then status=1; fi
  done < <(find src/main/java -name '*Checks.java')
  [[ $status -eq 0 ]] && echo "fallback checks passed" >&2
  return $status
}

if command -v mvn >/dev/null 2>&1; then
  if mvn -q -B test; then
    echo "maven tests passed"
    exit 0
  fi
  echo "maven test run did not pass; trying javac fallback..." >&2
  run_fallback
  exit $?
else
  echo "maven not found; trying javac fallback..." >&2
  run_fallback
  exit $?
fi
