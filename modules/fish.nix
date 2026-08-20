{ ... }:
{

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish

      set -gx EDITOR nixvim-editor

      bind ctrl-space accept-autosuggestion
      bind alt-space  accept-autosuggestion
      bind ₹          accept-autosuggestion
      bind shift-tab  accept-autosuggestion
    '';

    shellAliases = {
      nixvim = "nix run github:Ryuzaki5100/nixvim --refresh";
      rebuild-home-manager = "home-manager switch --flake ~/dotfiles#(whoami) && exec fish";
      update-home-manager = "cd ~/dotfiles && nix flake update && cd -";
      search = "nix search nixpkgs";
      display = "chafa -f kitty --fit-width";
      clock = "clock-rs -c bright-black -B -b";
      edot = "cd ~/dotfiles && nixvim";
      dot = "cd ~/dotfiles";
      ga = "git add .";
      op = "opencode";
      yt = "~/dotfiles/scripts/download-vid.sh";
    };

    functions = {
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
