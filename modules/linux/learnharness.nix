{ config, pkgs, ... }:

let
  dataDir = "${config.home.homeDirectory}/learning/learnharness-data";
  profileBin = "${config.home.profileDirectory}/bin";
in
{
  # The same standalone server the macOS bundle runs, as a user service. It is
  # reachable on 127.0.0.1:4747; expose it over the tailnet deliberately with
  # `tailscale serve` (and LH_HOST/LH_ALLOWED_HOSTS documented in the README).
  systemd.user.services.learnharness = {
    Unit = {
      Description = "LearnHarness learning server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      # Refuses to start when the remote moved and local additions are
      # unresolved; a clean or untouched tree starts normally.
      ExecStartPre = "${profileBin}/lh-sync pull";
      ExecStart = "${profileBin}/learnharness";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "LH_DATA_DIR=${dataDir}"
        "PORT=4747"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Push while idle so a teaching session on the Pi reaches the Mac without
  # waiting for a shutdown. cycle skips while a turn, job or extraction runs.
  systemd.user.services.learnharness-sync = {
    Unit.Description = "Push LearnHarness learning records when idle";
    Service = {
      Type = "oneshot";
      ExecStart = "${profileBin}/lh-sync cycle";
      Environment = [ "LH_DATA_DIR=${dataDir}" ];
    };
  };

  systemd.user.timers.learnharness-sync = {
    Unit.Description = "Periodic LearnHarness data sync";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      Unit = "learnharness-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
