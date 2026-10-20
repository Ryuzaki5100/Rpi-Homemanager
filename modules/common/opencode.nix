{ config, pkgs, lib, ... }:

let
  skillsDir = ../../skills;

  # Every file under skills/ is deployed, preserving the relative layout, so a
  # skill can route to SKILL.md, GUIDE.md, references/*.md, templates/ and
  # scripts/ from its deployed base directory (not just SKILL.md + GUIDE.md).
  allFiles = lib.filesystem.listFilesRecursive skillsDir;
  relPath = path: lib.removePrefix "${toString skillsDir}/" (toString path);

  # Only files nested inside a skill directory (>=2 path segments) and not
  # dotfiles like .DS_Store.
  isSkillFile = path:
    let rel = relPath path;
    in lib.hasInfix "/" rel
       && !(lib.hasPrefix "." (baseNameOf rel))
       && !(lib.hasInfix "/." rel);

  # Keep scripts executable after being symlinked out of the Nix store.
  isScript = path:
    let rel = relPath path;
    in lib.hasSuffix ".sh" rel || lib.hasInfix "/scripts/" rel;

  skillFiles = builtins.listToAttrs (map
    (path: {
      name = "opencode/skills/${relPath path}";
      value = { source = path; } // lib.optionalAttrs (isScript path) { executable = true; };
    })
    (builtins.filter isSkillFile allFiles));
in {
  programs.opencode = {
    enable = true;
    settings = {
      model = "opencode/deepseek-v4-flash-free";
      mcp = {
        gmail = {
          type = "local";
          enabled = true;
          command = [ "uv" "run" "--no-project" "--with" "mcp-google-gmail" "--with" "mcp>=1.8.0,<2" "mcp-google-gmail" ];
          environment = {
            GMAIL_CREDENTIALS_PATH = "${config.home.homeDirectory}/.config/gmail-mcp/credentials.json";
            GMAIL_TOKEN_PATH = "${config.home.homeDirectory}/.config/gmail-mcp/token.json";
          };
        };
      };
    };
  };

  xdg.configFile = skillFiles;
}
