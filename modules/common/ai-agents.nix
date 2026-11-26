# Pro-dev agents, commands and the OpenCode pro profile.
#
# One source (ai/roles.nix + ai/roles/*.md) rendered into:
#   - ~/.config/opencode/agents/*.md            (normal profile)
#   - ~/.config/opencode-pro/opencode/agents/*.md (pro profile, `opp`)
#   - ~/.claude/agents/*.md                     (Claude Code, `ccp`)
{ config, lib, pkgs, ... }:

let
  roles = import ../../ai/roles.nix;
  renderers = import ../../ai/lib.nix { inherit lib; };

  opencodeAgents = lib.mapAttrs (_: role: renderers.opencodeAgent role) roles;
  claudeAgents = lib.mapAttrs (name: role: renderers.claudeAgent name role) roles;

  prodevCommand = builtins.readFile ../../ai/commands/prodev.md;
  jsonFormat = pkgs.formats.json { };

  # The pro profile is the normal config plus a different default agent/model.
  # Sessions' model is stored separately from the agent, so the profile has to
  # set it explicitly for the orchestrator to actually run on the pro model.
  proSettings = config.programs.opencode.settings // {
    default_agent = "pro-dev";
    model = "opencode-go/deepseek-v4-pro#high";
    skills = [ "${config.xdg.configHome}/opencode/skills" ];
  };
in
{
  home.packages = [ pkgs.prodev ];

  programs.opencode = {
    agents = opencodeAgents;
    commands.prodev = prodevCommand;
  };

  programs.claude-code = {
    agents = claudeAgents;
    commands.prodev = prodevCommand;
  };

  xdg.configFile = lib.mkMerge [
    {
      "opencode-pro/opencode/opencode.json".source = jsonFormat.generate "opencode-pro.json" (
        { "$schema" = "https://opencode.ai/config.json"; } // proSettings
      );
      "opencode-pro/opencode/commands/prodev.md".text = prodevCommand;
      "opencode-pro/opencode/plugins/rtk.ts".source = ./rtk-opencode.ts;
    }
    # OpenCode only discovers agents from its own config directory, so the pro
    # profile gets the same rendered files. Same source, no drift.
    (lib.mapAttrs' (name: content:
      lib.nameValuePair "opencode-pro/opencode/agents/${name}.md" { text = content; }
    ) opencodeAgents)
  ];
}
