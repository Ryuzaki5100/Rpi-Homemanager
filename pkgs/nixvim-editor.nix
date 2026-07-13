{ writeShellScriptBin }:

writeShellScriptBin "nixvim-editor" ''
  exec nix run github:Ryuzaki5100/nixvim --refresh -- "$@"
''
