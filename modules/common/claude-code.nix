# Claude Code (TUI only).
#
# Three layers, deliberately:
#
#   ~/.claude/settings.json          real file (installed at activation), always
#                                    loaded: theme, model, effort, shared skills,
#                                    statusline, account-skill sync off
#   ~/.claude/prodev/settings.json   loaded only by `ccp` (via `prodev claude`):
#                                    agent, effort, PRODEV_MODE, hooks
#   ~/.claude/prodev/worker*.json    headless workers launched by `prodev dispatch`
#
# Plain `claude` never sees the pro layer, so nothing pro-dev starts, runs or
# costs tokens unless the session was launched with `ccp`.
#
# settings.json is installed as a *real* file rather than a Nix symlink: Claude
# persists `/effort`, `/model` and `/config` by writing an atomic temp file next
# to it, which fails with EACCES inside the read-only /nix/store.
{ config, lib, pkgs, ... }:

let
  prodev = "${config.home.profileDirectory}/bin/prodev";
  jsonFormat = pkgs.formats.json { };

  baseSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    theme = "auto";
    model = "opus";

    # Settings-level effort is what the main thread honours; an agent's
    # `effort` frontmatter only governs the subagents it spawns.
    effortLevel = "high";

    # The only personal skills are the ones Home Manager deploys; don't pull
    # a second set from the account.
    syncClaudeAiSkills = false;

    statusLine = {
      type = "command";
      command = "${prodev} status --line";
    };

    # Settings permissions are session-wide: they cannot express "workers may
    # push, the orchestrator may not". Role policy therefore lives in
    # `prodev hook guard-bash`, which sees `agent_type`. Only rules that are
    # right for every role stay here.
    permissions = {
      allow = [
        "Read"
        "Grep"
        "Glob"
      ];
      deny = [
        "Bash(rm -rf:*)"
      ];
    };
  };

  settingsFile = jsonFormat.generate "claude-code-settings.json" baseSettings;

  # Pro-dev orchestrator session.
  proSettings = {
    agent = "pro-dev";
    effortLevel = "high";
    env = {
      PRODEV_MODE = "1";
    };
    permissions = {
      allow = [
        "Bash(prodev:*)"
        "Bash(gh:*)"
        # All git commands are pre-approved for the session so a background
        # worker never stalls on an approval prompt. The hook still denies the
        # orchestrator's commit/push and everyone's force-push/destructive
        # commands, which is the only layer that knows the agent type.
        "Bash(git:*)"
        "Bash(rg:*)"
        "Bash(ls:*)"
        "Bash(find:*)"
      ];
      # No deny list here: these settings apply to the whole session, workers
      # included. Commit/push/destructive rules are enforced by
      # `prodev hook guard-bash`, which can tell the orchestrator from a worker.
    };
    hooks = {
      # Re-inject the vault after every start, resume, clear and compaction.
      SessionStart = [
        {
          matcher = "startup|resume|clear|compact";
          hooks = [
            {
              type = "command";
              command = "${prodev} hook session-start";
              timeout = 20;
            }
          ];
        }
      ];
      PostCompact = [
        {
          hooks = [
            {
              type = "command";
              command = "${prodev} hook post-compact";
              timeout = 10;
            }
          ];
        }
      ];
      PreToolUse = [
        {
          matcher = "Agent";
          hooks = [
            {
              type = "command";
              command = "${prodev} hook guard-spawn";
              timeout = 10;
            }
          ];
        }
        {
          matcher = "Bash";
          "if" = "Bash(git *)";
          hooks = [
            {
              type = "command";
              command = "${prodev} hook guard-bash";
              timeout = 10;
            }
          ];
        }
      ];
    };
  };

  # Headless worker sessions launched by `prodev dispatch`. Edits are
  # auto-approved; push/reset stay denied. One overlay per instance class so
  # the lite tier really runs at medium effort.
  workerSettings =
    tier: effort:
    {
      agent = if tier == "lite" then "pro-worker-lite" else "pro-worker";
      effortLevel = effort;
      env = {
        PRODEV_MODE = "1";
        PRODEV_WORKER = "1";
      };
      permissions = {
        defaultMode = "acceptEdits";
        allow = [ "Bash" "Read" "Write" "Edit" "Grep" "Glob" "TodoWrite" ];
        # No deny list: `prodev hook guard-bash` blocks force-push and the
        # destructive commands for workers too, and it has the agent type.
      };
    };
in
{
  programs.claude-code = {
    enable = true;

    # Leave the module's settings writer off: that file is a store symlink,
    # which breaks in-session writes. The activation hook below installs the
    # generated settings as a normal writable file instead.
    settings = { };

    # Same 29 skills as OpenCode, deployed from the shared skills/ tree.
    skills = ../../skills;

    context = ./claude/CLAUDE.md;
  };

  home.file = {
    ".claude/prodev/settings.json".source =
      jsonFormat.generate "claude-prodev-settings.json" proSettings;
    ".claude/prodev/worker.settings.json".source =
      jsonFormat.generate "claude-prodev-worker.settings.json" (workerSettings "work" "high");
    ".claude/prodev/worker-lite.settings.json".source =
      jsonFormat.generate "claude-prodev-worker-lite.settings.json" (workerSettings "lite" "medium");
  };

  # Install settings.json as a real file so `/effort`, `/model` and `/config`
  # can persist. Runs after linking so a stale symlink from an older generation
  # is gone first; only rewrites when the content actually changed, so a switch
  # does not churn the mtime needlessly.
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="$HOME/.claude/settings.json"
    $DRY_RUN_CMD mkdir -p "$HOME/.claude"
    if [ -L "$target" ]; then
      $DRY_RUN_CMD rm -f "$target"
    fi
    if ! ${pkgs.diffutils}/bin/cmp -s ${settingsFile} "$target"; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 ${settingsFile} "$target"
    fi
  '';
}
