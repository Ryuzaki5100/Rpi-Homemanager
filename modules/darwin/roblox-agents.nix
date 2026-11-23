{ config, pkgs, lib, ... }:

# Vault-driven multi-agent workflow for Roblox projects.
#
# Three things are pinned here so a fresh machine can reproduce the workflow:
#
#   1. the `noclip` dispatcher (scripts/noclip.sh, linted into a store path),
#   2. the role definitions in agents/ deployed as global OpenCode agents,
#   3. the vault location as a session variable, so `noclip` works from any cwd.
#
# The vault *contents* are not managed here on purpose: they are project data
# that agents write to. `noclip init` scaffolds them idempotently from the
# installed script, which keeps the shape reproducible without making the vault
# a read-only store path.
let
  home = config.home.homeDirectory;

  agentsDir = ../../agents;
  relPath = path: lib.removePrefix "${toString agentsDir}/" (toString path);

  # Deploy every agents/*.md preserving the name; a nested path becomes a
  # namespaced agent ID (opencode/agents/team/x.md -> team/x).
  agentFiles = builtins.listToAttrs (
    map
      (path: {
        name = "opencode/agents/${relPath path}";
        value.source = path;
      })
      (builtins.filter (lib.hasSuffix ".md") (lib.filesystem.listFilesRecursive agentsDir))
  );
in
{
  home.packages = [ pkgs.noclip pkgs.lore-ingest ];

  xdg.configFile = agentFiles;

  home.sessionVariables = {
    NOCLIP_VAULT = "${home}/roblox/noclip-protocol-vault";
    NOCLIP_REPO = "${home}/roblox/backrooms";
  };
}
