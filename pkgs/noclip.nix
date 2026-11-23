{
  lib,
  runCommandLocal,
  writeShellScriptBin,
  shellcheck,
}:

# The orchestrator is a plain POSIX sh script kept next to the other repo
# scripts (scripts/noclip.sh) so it can be read and diffed like any other file.
# This package pins it into the store, lints it at build time, and ships the
# canonical agent role set beside it. Agents are *installed into a project*
# (`noclip agents install`) rather than loaded globally, so they only exist
# while working on a Roblox project.
let
  base = runCommandLocal "noclip" { nativeBuildInputs = [ shellcheck ]; } ''
    shellcheck --shell=sh --severity=warning ${../scripts/noclip.sh}
    install -Dm755 ${../scripts/noclip.sh} $out/libexec/noclip
    mkdir -p $out/share/noclip
    cp -r ${../agents} $out/share/noclip/agents
  '';
in
writeShellScriptBin "noclip" ''
  export NOCLIP_AGENTS_DIR="${base}/share/noclip/agents"
  exec ${base}/libexec/noclip "$@"
''
