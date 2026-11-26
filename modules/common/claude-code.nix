# Claude Code (TUI only).
#
# Two layers, deliberately:
#
#   ~/.claude/settings.json          always loaded: theme, model, shared skills,
#                                    statusline, account-skill sync off
#   ~/.claude/prodev/settings.json   loaded only by `ccp` (via `prodev claude`):
#                                    agent, PRODEV_MODE, pro permissions, hooks
#
# Plain `claude` never sees the pro layer, so nothing pro-dev starts, runs or
# costs tokens unless the session was launched with `ccp`.
{ config, lib, pkgs, ... }:

let
  prodev = "${config.home.profileDirectory}/bin/prodev";
  jsonFormat = pkgs.formats.json { };

  # Pro-dev orchestrator session.
  proSettings = {
    agent = "pro-dev";
    env = {
      PRODEV_MODE = "1";
    };
    permissions = {
      allow = [
        "Bash(prodev:*)"
        "Bash(gh:*)"
        "Bash(git status:*)"
        "Bash(git log:*)"
        "Bash(git diff:*)"
        "Bash(git merge:*)"
        "Bash(rg:*)"
        "Bash(ls:*)"
        "Bash(find:*)"
      ];
      deny = [
        "Bash(git push:*)"
        "Bash(git reset --hard:*)"
        "Bash(git clean -fdx:*)"
        "Bash(rm -rf:*)"
      ];
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
  # auto-approved; push/reset stay denied.
  workerSettings = {
    agent = "pro-worker";
    env = {
      PRODEV_MODE = "1";
      PRODEV_WORKER = "1";
    };
    permissions = {
      defaultMode = "acceptEdits";
      allow = [ "Bash" "Read" "Write" "Edit" "Grep" "Glob" "TodoWrite" ];
      deny = [
        "Bash(git push:*)"
        "Bash(git reset --hard:*)"
      ];
    };
  };
in
{
  programs.claude-code = {
    enable = true;

    settings = {
      theme = "auto";
      model = "opus";

      # The only personal skills are the ones Home Manager deploys; don't pull
      # a second set from the account.
      syncClaudeAiSkills = false;

      statusLine = {
        type = "command";
        command = "${prodev} status --line";
      };

      permissions = {
        allow = [
          "Read"
          "Grep"
          "Glob"
        ];
        deny = [
          "Bash(git push:*)"
          "Bash(rm -rf:*)"
        ];
      };
    };

    # Same 29 skills as OpenCode, deployed from the shared skills/ tree.
    skills = ../../skills;

    context = ./claude/CLAUDE.md;
  };

  home.file = {
    ".claude/prodev/settings.json".source =
      jsonFormat.generate "claude-prodev-settings.json" proSettings;
    ".claude/prodev/worker.settings.json".source =
      jsonFormat.generate "claude-prodev-worker.settings.json" workerSettings;
  };

  # Earlier hand-written settings are not a Home Manager symlink, which makes
  # activation refuse to replace them (checkLinkTargets runs before linking).
  # Move it aside once, keeping the content.
  home.activation.claudeLegacySettings = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -f "$HOME/.claude/settings.json" ] && [ ! -L "$HOME/.claude/settings.json" ]; then
      $DRY_RUN_CMD mv "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.pre-hm"
    fi
  '';
}
