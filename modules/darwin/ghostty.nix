{ config, lib, pkgs, ... }:

let
  stateDir = "${config.home.homeDirectory}/.local/state/ghostty";

  # Ghostty processes `config-file` includes *after* the whole main file, so a
  # one-line override written at runtime always wins over the default theme
  # declared below. The leading `?` makes the include optional: if the file is
  # absent (never switched themes) Ghostty silently ignores it.
  themeOverride = "${stateDir}/theme.ghostty";
in
{
  programs.ghostty = {
    enable = true;

    # Prebuilt Ghostty.app (1.3.1) from nixpkgs — no Homebrew cask needed. Home
    # Manager copies the bundle into ~/Applications/Home Manager Apps and puts
    # the `ghostty` CLI wrapper on PATH.
    package = pkgs.ghostty-bin;

    # Ghostty exports $GHOSTTY_RESOURCES_DIR to every shell it spawns, so this
    # wires shell integration into fish automatically.
    enableFishIntegration = true;

    settings = {
      # Runtime theme override, written by `ghostty-set-theme` (state dir, not
      # tracked) so switching themes survives `home-manager switch`.
      config-file = "?${themeOverride}";

      # Default theme. Change live with `ghostty-set-theme`.
      theme = "Catppuccin Mocha";

      # Font — nerd-fonts.jetbrains-mono is installed below.
      font-family = "JetBrainsMono Nerd Font";
      font-size = 13;
      font-thicken = true;

      # Transparency + blur (the pretty stuff).
      background-opacity = 0.92;
      background-blur = true;
      window-colorspace = "display-p3";

      # Comfort / polish.
      window-padding-x = 12;
      window-padding-y = 8;
      window-padding-balance = true;
      cursor-style = "block";
      cursor-style-blink = false;
      mouse-hide-while-typing = true;
      copy-on-select = "clipboard";
      confirm-close-surface = false;
      shell-integration = "detect";
      macos-option-as-alt = true;
    };
  };

  # Nerd Font for icons/glyphs. Home Manager links it into ~/Library/Fonts/
  # HomeManager on macOS (same mechanism as dejavu_fonts in epub.nix).
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Interactive theme picker, mirroring `glow-set-theme`: the chosen theme is
  # written to runtime state, leaving the managed config untouched.
  programs.fish.functions."ghostty-set-theme" = {
    description = "Pick the Ghostty theme (persisted via state override)";
    body = ''
      set -l state_dir "$HOME/.local/state/ghostty"
      set -l override "$state_dir/theme.ghostty"

      # Prefer the wrapper Home Manager puts on PATH, then well-known bundles.
      set -l ghostty_bin (command -s ghostty)
      if test -z "$ghostty_bin"
          for candidate in \
              /Applications/Ghostty.app/Contents/MacOS/ghostty \
              "$HOME/Applications/Home Manager Apps/Ghostty.app/Contents/MacOS/ghostty"
              if test -x "$candidate"
                  set ghostty_bin "$candidate"
                  break
              end
          end
      end
      if test -z "$ghostty_bin"
          echo "ghostty-set-theme: ghostty binary not found" >&2
          return 1
      end

      if test "$argv[1]" = "--reset"
          rm -f "$override"
          echo "ghostty theme override cleared (dotfiles default applies)"
          return 0
      end

      # Built-in + user themes, stripped of the " (resources)"/" (user)" suffix.
      set -l names
      for line in ($ghostty_bin +list-themes --plain 2>/dev/null)
          set -a names (string replace -r ' \((resources|user)\)$' "" -- "$line")
      end
      set names (printf '%s\n' $names | sort -u)

      if test (count $names) -eq 0
          echo "ghostty-set-theme: no themes found" >&2
          return 1
      end

      set -l chosen
      if test (count $argv) -ge 1
          if not contains -- "$argv[1]" $names
              echo "ghostty-set-theme: unknown theme '$argv[1]'" >&2
              echo "use 'ghostty-set-theme' with no argument to browse" >&2
              return 1
          end
          set chosen "$argv[1]"
      else
          set chosen (printf '%s\n' $names | fzf --height 85% --reverse --ansi \
              --prompt 'ghostty theme> ' \
              --preview 'fish -c "_ghostty-theme-preview {}"' \
              --preview-window 'right,55%,border-left')
          or return 0
      end

      mkdir -p "$state_dir"
      printf 'theme = %s\n' "$chosen" > "$override"
      echo "ghostty theme set to: $chosen"
      echo "Ghostty reloads on save; if not, press cmd+shift+, (macOS)."
    '';
  };

  # Private helper for `ghostty-set-theme`: renders a color swatch preview of a
  # theme by parsing its palette/background/foreground into ANSI truecolor.
  programs.fish.functions."_ghostty-theme-preview" = {
    description = "Render a color swatch for a Ghostty theme (internal)";
    body = ''
      set -l name $argv[1]

      # Ghostty sets $GHOSTTY_RESOURCES_DIR for its shells; fall back to the
      # installed .app bundle if it is missing.
      set -l resources $GHOSTTY_RESOURCES_DIR
      if test -z "$resources"
          for candidate in \
              /Applications/Ghostty.app/Contents/Resources/ghostty \
              "$HOME/Applications/Home Manager Apps/Ghostty.app/Contents/Resources/ghostty"
              if test -d "$candidate"
                  set resources "$candidate"
                  break
              end
          end
      end

      set -l file
      for candidate in "$HOME/.config/ghostty/themes/$name" "$resources/themes/$name"
          if test -f "$candidate"
              set file "$candidate"
              break
          end
      end
      if test -z "$file"
          echo "No preview available for \"$name\""
          return 0
      end

      set -l bg 1e1e2e
      set -l fg cdd6f4
      set -l pal
      while read -l line
          set -l m (string match -r '^background\s*=\s*#?([0-9a-fA-F]{6})' -- "$line")
          if test (count $m) -ge 2
              set bg $m[2]
          end
          set m (string match -r '^foreground\s*=\s*#?([0-9a-fA-F]{6})' -- "$line")
          if test (count $m) -ge 2
              set fg $m[2]
          end
          set m (string match -r '^palette\s*=\s*([0-9]+)\s*=\s*#?([0-9a-fA-F]{6})' -- "$line")
          if test (count $m) -ge 3
              set -a pal $m[2]:$m[3]
          end
      end < "$file"

      set -l bgr (printf '%d' 0x(string sub -s 1 -l 2 -- $bg))
      set -l bgg (printf '%d' 0x(string sub -s 3 -l 2 -- $bg))
      set -l bgb (printf '%d' 0x(string sub -s 5 -l 2 -- $bg))
      set -l fgr (printf '%d' 0x(string sub -s 1 -l 2 -- $fg))
      set -l fgg (printf '%d' 0x(string sub -s 3 -l 2 -- $fg))
      set -l fgb (printf '%d' 0x(string sub -s 5 -l 2 -- $fg))

      printf '\033[1m%s\033[0m\n\n' "$name"
      printf '\033[48;2;%d;%d;%dm\033[38;2;%d;%d;%dm   AaBbCc 0123 !@#   \033[0m\n\n' \
          $bgr $bgg $bgb $fgr $fgg $fgb

      for entry in $pal
          set -l parts (string split ':' -- $entry)
          set -l r (printf '%d' 0x(string sub -s 1 -l 2 -- $parts[2]))
          set -l g (printf '%d' 0x(string sub -s 3 -l 2 -- $parts[2]))
          set -l b (printf '%d' 0x(string sub -s 5 -l 2 -- $parts[2]))
          printf '\033[48;2;%d;%d;%dm    \033[0m' $r $g $b
      end
      printf '\n'
    '';
  };
}
