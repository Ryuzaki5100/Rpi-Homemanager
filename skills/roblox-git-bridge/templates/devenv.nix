{ pkgs, ... }:
let
  identity = builtins.fromJSON (builtins.readFile ./roblox.json);
  game = identity.game;
  placeId = if game.placeId == null then "" else toString game.placeId;
  universeId = if game.universeId == null then "" else toString game.universeId;
in {
  packages = with pkgs; [
    rojo
    selene
    stylua
    luau-lsp
    luau
    lune
    git
    jq
    curl
  ];

  env = {
    ROBLOX_PLACE_FILE = identity.placeFile;
    ROBLOX_PLACE_NAME = game.name;
    ROBLOX_PLACE_ID = placeId;
    ROBLOX_UNIVERSE_ID = universeId;
    ROBLOX_SENTINEL = identity.sentinel;
  };

  # One Rojo server only: never run `rojo serve` alongside this.
  processes.rojo.exec = "rojo serve --port 34872";

  scripts = {
    roblox-studio-mcp.exec = ''exec "$DEVENV_ROOT/scripts/studio-mcp.sh"'';
    studio-open.exec = ''exec "$DEVENV_ROOT/scripts/studio-open.sh" "$@"'';
    status.exec = ''exec "$DEVENV_ROOT/scripts/status.sh" "$@"'';
    sync.exec = ''exec "$DEVENV_ROOT/scripts/sync.sh" "$@"'';
    preflight.exec = ''exec "$DEVENV_ROOT/scripts/preflight.sh" "$@"'';
    lint.exec = "selene src";
    fmt.exec = "stylua src";
    build.exec = "rojo build default.project.json -o ${identity.placeFile}";
    sourcemap.exec = "rojo sourcemap default.project.json --output sourcemap.json";
  };

  # devenv 2.x: the legacy enterTest option leaves the task without a command.
  tasks."devenv:enterTest".exec = ''
    mkdir -p build
    selene src
    stylua --check src
    rojo build default.project.json -o build/test.rbxlx
  '';
}
