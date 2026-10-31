{ ... }:
{

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # The official multi-user Nix installer (Linux and macOS) uses this path;
      # guard it so a single-user install does not error.
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
      rebuild-home-manager = "~/dotfiles/scripts/sync-rtk-plugin.sh && home-manager switch --impure --flake ~/dotfiles#(whoami) && exec fish";
      update-home-manager = "cd ~/dotfiles && nix flake update && ./scripts/sync-rtk-plugin.sh && cd -";
      search = "nix search nixpkgs";
      display = "chafa -f kitty --fit-width";
      clock = "clock-rs -c bright-black -B -b";
      edot = "cd ~/dotfiles && nixvim";
      dot = "cd ~/dotfiles";
      ga = "git add .";
      yt = "~/dotfiles/scripts/download-vid.sh";
      build-epubs = "~/dotfiles/scripts/build-epubs.sh";
      crt = "retrocrt";
      sz = "du -sh ";
      opt = "nix-store --optimise";
      collect-garbage = "nix-collect-garbage";
    };

    functions = {
      # Shorthand for opencode. A global RTK_DISABLED=1 (see env.nix) keeps
      # token compression off; use `oprtk` for a session with it enabled.
      op = {
        description = "Shorthand for opencode";
        body = ''
          opencode $argv
        '';
      };

      # opencode with RTK token compression enabled for this session only.
      # rtk-opencode.ts (see opencode.nix) only checks for the string "1", so
      # setting the variable to 0 turns the plugin on for the child process.
      oprtk = {
        description = "Shorthand for opencode with RTK token compression enabled";
        body = ''
          set -lx RTK_DISABLED 0
          opencode $argv
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

  # fish 4.9 ships an embedded `completions/op.fish` that runs
  # `op completion fish | source`. Our `op` is a wrapper around opencode, not
  # the real binary, so that call made opencode print its help text, which
  # fish then tried to execute as fish code (a wall of `Unknown command`
  # errors whenever `op ` was completed). A user completion file takes
  # precedence over the embedded one, so shadow it. `oprtk` gets its
  # completions the same way.
  xdg.configFile = {
    "fish/completions/op.fish".text = "complete -c op -w opencode\n";
    "fish/completions/oprtk.fish".text = "complete -c oprtk -w opencode\n";
  };
}
