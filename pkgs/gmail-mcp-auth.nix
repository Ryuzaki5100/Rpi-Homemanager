{ lib, python3, writeShellScriptBin, writeText }:

let
  pythonEnv = python3.withPackages (ps: [ ps.google-auth-oauthlib ]);
  scriptPath = ../scripts/gmail-mcp-auth.py;
in
writeShellScriptBin "gmail-mcp-auth" ''
  exec ${pythonEnv}/bin/python3 "${scriptPath}" "$@"
''