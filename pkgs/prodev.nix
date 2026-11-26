{ lib, writeShellScriptBin, runCommand, bash, git, gh, jq, gnused, gawk, coreutils, curl }:

let
  templates = runCommand "prodev-templates" { } ''
    mkdir -p $out
    cp -R ${../ai/templates}/. $out/
  '';

  # Runtime PATH for the script: everything it shells out to, without taking
  # over the caller's PATH (opencode/claude still come from the user's profile).
  toolPath = lib.makeBinPath [ git gh jq gnused gawk coreutils curl ];
in
writeShellScriptBin "prodev" ''
  export PATH="${toolPath}:$PATH"
  export PRODEV_TEMPLATES="${templates}"
  exec ${bash}/bin/bash ${../scripts/prodev.sh} "$@"
''
