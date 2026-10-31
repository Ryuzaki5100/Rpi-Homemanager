{ pkgs, ... }:

# macOS-only: `opl` opens opencode against LM Studio's local server, exposing
# only models that are present on disk and fit this machine's RAM.
let
  opl = pkgs.writers.writePython3Bin "opl" { } (builtins.readFile ./opl.py);
in {
  home.packages = [ opl ];
}
