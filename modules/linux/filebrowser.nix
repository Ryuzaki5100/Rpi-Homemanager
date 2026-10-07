{ config, pkgs, lib, ... }:

# Linux Filebrowser service (systemd user unit). Options live in
# modules/common/filebrowser.nix.
let
  cfg = config.services.filebrowser;
  db = "${config.home.homeDirectory}/.config/filebrowser/filebrowser.db";
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.filebrowser = {
      Unit = {
        Description = "Filebrowser web file manager";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStartPre = cfg.initScript;
        ExecStart = "${pkgs.filebrowser}/bin/filebrowser --address ${cfg.address} --port ${toString cfg.port} --root ${cfg.root} --database ${db}";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
