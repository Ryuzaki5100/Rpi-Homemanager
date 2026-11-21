#!/usr/bin/env bash
# Re-vendor the LearnHarness agent skills from the pinned app derivation.
#
#   skills/learnharness          the read-only learning-data skill
#   skills/learnharness-plugins  the app's generated portable authoring bundle
#
# Both payloads come out of `nix build .#learnharness`, so the vendored copy
# can never drift from the app version the dotfiles build. Run after bumping
# `version` in pkgs/learnharness.nix, and commit the resulting skill files
# (flake inputs only see tracked files).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
SKILLS="${REPO}/skills"

info() { printf '[lh-skill-sync] %s\n' "$*"; }

version="$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "${REPO}/pkgs/learnharness.nix" | head -n1)"
if [ -z "${version}" ]; then
  info "could not read version from pkgs/learnharness.nix"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

info "building learnharness ${version}"
nix build "${REPO}#learnharness" --out-link "${tmp}/result" --print-build-logs >/dev/null

src="${tmp}/result/share/learnharness"
for required in \
  "${src}/skills/learnharness/SKILL.md" \
  "${src}/plugin-authoring/SKILL.md" \
  "${src}/plugin-authoring/bundle.json"; do
  if [ ! -f "${required}" ]; then
    info "missing payload: ${required}"
    exit 1
  fi
done

bundle_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["appVersion"])' "${src}/plugin-authoring/bundle.json")"
if [ "${bundle_version}" != "${version}" ]; then
  info "bundle appVersion ${bundle_version} does not match derivation ${version}"
  exit 1
fi

rm -rf "${SKILLS}/learnharness" "${SKILLS}/learnharness-plugins"
cp -R "${src}/skills/learnharness" "${SKILLS}/learnharness"
cp -R "${src}/plugin-authoring" "${SKILLS}/learnharness-plugins"
chmod -R u+w "${SKILLS}/learnharness" "${SKILLS}/learnharness-plugins"

printf '%s\n' "${version}" > "${SKILLS}/learnharness/VERSION"
printf '%s\n' "${version}" > "${SKILLS}/learnharness-plugins/VERSION"

cat >> "${SKILLS}/learnharness/SKILL.md" <<'EOF'

## Local setup (dotfiles)

This deployment keeps the record in the synced `learnharness-data` repository.
`LH_DATA_DIR` points at it, so pass the directory explicitly:

```sh
python3 -B scripts/sessions.py --data-dir "$LH_DATA_DIR" list
```

The `lhtui` terminal companion reads the same path automatically. Never write
into that repository from this skill; `lh-sync` owns commits.
EOF

git -C "${REPO}" add skills/learnharness skills/learnharness-plugins
info "vendored ${version} (remember to commit the skill files)"
