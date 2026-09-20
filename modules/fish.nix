{ ... }:
{

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
          source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
      end

      set -gx EDITOR nixvim-editor

      bind ctrl-space accept-autosuggestion
      bind alt-space  accept-autosuggestion
      bind ₹          accept-autosuggestion
      bind shift-tab  accept-autosuggestion
    '';

    shellAliases = {
      nixvim = "nix run github:Ryuzaki5100/nixvim --refresh";
      # --impure lets the flake auto-detect the host architecture
      # (builtins.currentSystem) and the invoking user (USER).
      rebuild-home-manager = "home-manager switch --flake ~/dotfiles#(whoami) --impure && exec fish";
      update-home-manager = "cd ~/dotfiles && nix flake update && cd -";
      search = "nix search nixpkgs";
      display = "chafa -f kitty --fit-width";
      clock = "clock-rs -c bright-black -B -b";
      edot = "cd ~/dotfiles && nixvim";
      dot = "cd ~/dotfiles";
      ga = "git add .";
      op = "opencode";
      yt = "~/dotfiles/scripts/download-vid.sh";
      # Reapply the local Omarchy Spotify plugin patches after `omarchy plugin
      # update` (idempotent; self-skips where the plugin is not installed).
      spotify-patch = "bash ~/dotfiles/scripts/reapply-omarchy-spotify-patches.sh";
    };

    functions = {
      # Refresh the opencode theme from the active Omarchy palette, then
      # launch the real binary. `op` (alias) resolves here too.
      opencode = {
        description = "Launch opencode with the Omarchy theme refreshed";
        body = ''
          if type -q bash; and test -r $HOME/.config/opencode/omarchy-theme.sh
              bash $HOME/.config/opencode/omarchy-theme.sh >/dev/null 2>&1
          end
          command opencode $argv
        '';
      };

      # Control the Omarchy Spotify shell plugin. Omarchy-only: on other hosts
      # (e.g. the Raspberry Pi) it prints a clear message instead of failing.
      #   sp / sp full  open the full player
      #   sp mini       toggle the bar mini-player
      #   sp up/down    nudge Spotify's own volume by 5%
      sp = {
        description = "Control Omarchy Spotify";
        body = ''
          if not command -q omarchy
            echo "sp: Omarchy Spotify is only available on Omarchy" >&2
            return 1
          end
          set -l action toggleFullPlayer
          switch "$argv[1]"
            case mini
              set action toggleMiniPlayer
            case full
              set action toggleFullPlayer
            case up
              set action volumeUp
            case down
              set action volumeDown
          end
          omarchy shell -q quickshell.spotify.player $action
        '';
      };

      generate-ssh-key = {
        body = ''
          read -P "Enter your email: " email
          ssh-keygen -t ed25519 -C "$email"
        '';
      };

      # NixOS-only: rebuild the system from the rpi-nixos flake. On non-NixOS
      # hosts (Debian, RPi OS, ...) nixos-rebuild does not exist, so this
      # degrades to a friendly hint instead of failing.
      rebuild-nixos = {
        description = "Rebuild the NixOS system from the rpi-nixos flake";
        body = ''
          if not command -q nixos-rebuild
              echo "rebuild-nixos: nixos-rebuild not found — not a NixOS system (or nix is not on PATH)."
              return 1
          end
          if not test -d "$HOME/rpi-nixos"
              echo "rebuild-nixos: $HOME/rpi-nixos not found — clone Ryuzaki5100/rpi-nixos there first."
              return 1
          end
          sudo nixos-rebuild switch --flake "$HOME/rpi-nixos#"(hostname)
        '';
      };

      # Update the rpi-nixos flake lock file; harmless everywhere else.
      update-nixos = {
        description = "Update the rpi-nixos flake lock file";
        body = ''
          if not test -d "$HOME/rpi-nixos"
              echo "update-nixos: $HOME/rpi-nixos not found — clone Ryuzaki5100/rpi-nixos there first."
              return 1
          end
          nix flake update "$HOME/rpi-nixos"
        '';
      };
    };
  };
}
