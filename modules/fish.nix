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
      rebuild-home-manager = "home-manager switch --flake ~/dotfiles#ryuzaki && exec fish";
      update-home-manager = "cd ~/dotfiles && nix flake update && cd -";
      search = "nix search nixpkgs";
      display = "chafa -f kitty --fit-width";
      clock = "clock-rs -c bright-black -B -b";
    };
  };
}
