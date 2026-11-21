{ pkgs, ... }:

# macOS-only: `opl` unloads all LM Studio models, then opens opencode against
# the local server, exposing only loadable models under the "Local LLM"
# provider.
let
  opl = pkgs.writers.writePython3Bin "opl" { } (builtins.readFile ./opl.py);
in {
  home.packages = [ opl ];
}
