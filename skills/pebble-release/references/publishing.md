# Publishing

## Login

```bash
pebble login
pebble login --status
```

The login is a Pebble account, separate from npm/GitHub.

## Interactive publish

```bash
pebble publish
```

Prompts for:
- release notes,
- new-app metadata (name, description, category, icons, screenshots),
- upload confirmation.

## Non-interactive / CI

```bash
pebble publish --non-interactive \
  --name "My App" \
  --description "..." \
  --category daily \
  --release-notes "Initial release"
```

Common flags:
- `--release-notes TEXT`
- `--is-published` (accepted; current versions may ignore it)
- `--gif-all-platforms` / `--no-gif-all-platforms`
- `--all-platforms`
- `--name`, `--version`, `--description`, `--source`, `--category`
- `--icon-small FILE`, `--icon-large FILE`, `--screenshots FILE...`

Always run `pebble publish --help` for the installed version; flags have changed.

## Categories

`daily`, `tools`, `notifications`, `remotes`, `health`, `games` (verify the exact accepted names in `--help`).

## Release notes

- State what changed and what was tested.
- Mention required phone/PKJS features.
- Do not claim unverified platform support.
