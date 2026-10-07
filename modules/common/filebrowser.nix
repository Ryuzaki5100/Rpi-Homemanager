{ config, pkgs, lib, ... }:

# Shared Filebrowser options + package + the DB bootstrap script.
# The service definition lives in the platform layer: modules/linux/filebrowser.nix
# (systemd) and modules/darwin/filebrowser.nix (launchd).
let
  cfg = config.services.filebrowser;
  db = "${config.home.homeDirectory}/.config/filebrowser/filebrowser.db";
in
{
  options.services.filebrowser = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Filebrowser web file manager.";
    };
    root = lib.mkOption {
      type = lib.types.path;
      default = config.home.homeDirectory;
      description = "Root directory Filebrowser serves.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on.";
    };
    address = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address to listen on.";
    };
    username = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Admin username for the initial user.";
    };
    password = lib.mkOption {
      type = lib.types.str;
      default = "changeme";
      description = "Initial admin password (plaintext; Filebrowser hashes it). Placeholder only — set the real password via scripts/init-filebrowser.sh.";
    };
    tusChunkSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2147483648;
      description = ''
        TUS chunk size in bytes. Workaround for Safari freezing after the
        first chunk (filebrowser#5987): set larger than any file you upload
        so the browser sends a single chunk. Default 2 GiB.
      '';
    };
    initScript = lib.mkOption {
      type = lib.types.path;
      internal = true;
      description = ''
        Idempotent database bootstrap script. Shared by the Linux systemd unit
        (ExecStartPre) and the macOS launchd agent (run before exec).
      '';
      default = pkgs.writeShellScript "filebrowser-init" ''
        set -e
        mkdir -p "${config.home.homeDirectory}/.config/filebrowser"
        if [ ! -f "${db}" ]; then
          ${pkgs.filebrowser}/bin/filebrowser config init --database "${db}" >/dev/null
          ${pkgs.filebrowser}/bin/filebrowser config set --database "${db}" --minimumPasswordLength 8 >/dev/null
          ${pkgs.filebrowser}/bin/filebrowser config set --database "${db}" --tus.chunkSize ${toString cfg.tusChunkSize} >/dev/null
          ${pkgs.filebrowser}/bin/filebrowser --database "${db}" users add "${cfg.username}" '${cfg.password}' --perm.admin
        fi
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.filebrowser ];
  };
}
