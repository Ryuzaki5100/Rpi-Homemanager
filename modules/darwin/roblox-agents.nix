{ config, pkgs, ... }:

# Vault-driven multi-agent workflow for Roblox projects.
#
# Agent roles are deliberately NOT deployed to ~/.config/opencode/agents. They
# are project-scoped: `noclip agents install` copies them into
# <repo>/.opencode/agents, so the picker only shows them while working on a
# Roblox game, and the dispatcher resolves them from a git worktree too.
#
# What Home Manager provides:
#
#   1. the `noclip` dispatcher (scripts/noclip.sh) plus the canonical role set,
#   2. `lore-ingest` for the wiki corpus,
#   3. ~/roblox/.opencode/agents as a symlink to that role set, so an OpenCode
#      session opened anywhere under ~/roblox sees the agents without each
#      project having to be initialised first,
#   4. the vault location as a session variable.
let
  home = config.home.homeDirectory;
in
{
  home.packages = [ pkgs.noclip pkgs.lore-ingest ];

  # Directory symlink into the store: one source of truth, no drift, and the
  # roles appear for `~/roblox` itself and any sibling project that does not
  # carry its own .opencode yet.
  home.file."roblox/.opencode/agents".source = ../../agents;

  home.sessionVariables = {
    NOCLIP_VAULT = "${home}/roblox/noclip-protocol-vault";
    NOCLIP_REPO = "${home}/roblox/backrooms";
  };
}
