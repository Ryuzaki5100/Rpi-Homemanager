{
  lib,
  runCommandLocal,
  shellcheck,
}:

# The orchestrator is a plain POSIX sh script kept next to the other repo
# scripts (scripts/noclip.sh) so it can be read and diffed like any other file.
# The package only pins it into the store and lints it at build time; runtime
# tools (opencode, git, rojo, devenv) come from the project environment on
# purpose — the script must not shadow the versions a project has pinned.
runCommandLocal "noclip"
  {
    nativeBuildInputs = [ shellcheck ];
  }
  ''
    shellcheck --shell=sh --severity=warning ${../scripts/noclip.sh}
    install -Dm755 ${../scripts/noclip.sh} $out/bin/noclip
  ''
