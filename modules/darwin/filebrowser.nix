{ config, pkgs, lib, ... }:

# macOS Filebrowser service (launchd user agent). Options live in
# modules/common/filebrowser.nix. launchd has no ExecStartPre, so the shared
# bootstrap script is run by a wrapper before exec'ing filebrowser.
let
  cfg = config.services.filebrowser;
  db = "${config.home.homeDirectory}/.config/filebrowser/filebrowser.db";
  runScript = pkgs.writeShellScript "filebrowser-run" ''
    ${cfg.initScript}
    exec ${pkgs.filebrowser}/bin/filebrowser --address ${cfg.address} --port ${toString cfg.port} --root ${cfg.root} --database ${db}
  '';
in
{
  config = lib.mkIf cfg.enable {
    launchd.agents.filebrowser = {
      enable = true;
      config = {
        ProgramArguments = [ "${runScript}" ];
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
      };
    };
  };
}
