{ pkgs, lib, pebble, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  supported = lib.elem system [
    "x86_64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  version = "4.33.1";
  sdkRoot =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "Library/Application Support/Pebble SDK"
    else ".pebble-sdk";

  qemuPepple = pkgs.writeShellScriptBin "qemu-pebble" ''
    exec ${pebble.packages.${system}.pebble-qemu}/bin/qemu-pebble "$@"
  '';

  pypkjsPath = lib.makeSearchPath
    "lib/python${lib.versions.majorMinor pkgs.python3.version}/site-packages"
    (pkgs.pypkjs.requiredPythonModules ++ pkgs.pebble-tool.requiredPythonModules);

  # pebble-tool spawns `sys.executable -m pypkjs`; put pypkjs and its deps on
  # PYTHONPATH for that child process. Also pin the QEMU path absolutely so
  # version detection does not depend on shell PATH setup.
  pebbleTool = pkgs.writeShellScriptBin "pebble" ''
    export PEBBLE_QEMU_PATH="${qemuPepple}/bin/qemu-pebble"
    export PYTHONPATH="${pypkjsPath}''${PYTHONPATH:+:$PYTHONPATH}"
    exec ${pkgs.pebble-tool}/bin/pebble "$@"
  '';

  pythonWithPillow = pkgs.python3.withPackages (ps: [ ps.pillow ]);
  pebblePython = pkgs.writeShellScriptBin "pebble-python" ''
    exec ${pythonWithPillow}/bin/python3 "$@"
  '';
in
lib.mkIf supported {
  home.packages = [
    pebbleTool
    pkgs.pebble-sdk
    qemuPepple
    pebblePython
  ];

  home.sessionVariables = {
    PEBBLE_QEMU_PATH = "${qemuPepple}/bin/qemu-pebble";
    PEBBLE_EMULATOR = "emery";
    PEBBLE_PYTHON = "${pebblePython}/bin/pebble-python";
  };

  # Waf unpacks a helper into sdk-core, so the SDK tree must be user-writable.
  # Copy the Nix-packaged SDK into the location pebble-tool expects, and point
  # `current` at that copy. The copy is refreshed only when the Nix SDK changes.
  home.activation.pebbleSdk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sdk_base="$HOME/${sdkRoot}"
    sdk_dir="$sdk_base/SDKs/${version}"
    marker="$sdk_dir/.nix-sdk-source"
    $DRY_RUN_CMD mkdir -p "$sdk_dir"
    if [ "$(cat "$marker" 2>/dev/null || true)" != "${pkgs.pebble-sdk}" ]; then
      $DRY_RUN_CMD rm -rf "$sdk_dir/sdk-core" "$sdk_dir/toolchain"
      $DRY_RUN_CMD cp -R ${pkgs.pebble-sdk}/sdk-core "$sdk_dir/sdk-core"
      $DRY_RUN_CMD cp -R ${pkgs.pebble-sdk}/toolchain "$sdk_dir/toolchain"
      $DRY_RUN_CMD chmod -R u+w "$sdk_dir/sdk-core" "$sdk_dir/toolchain"
      $DRY_RUN_CMD printf '%s\n' "${pkgs.pebble-sdk}" > "$marker"
    fi
    $DRY_RUN_CMD ln -sfn ${pkgs.pebble-sdk}/.venv "$sdk_dir/.venv"
    $DRY_RUN_CMD ln -sfn ${pkgs.pebble-sdk}/node_modules "$sdk_dir/node_modules"
    $DRY_RUN_CMD ln -sfn "$sdk_dir" "$sdk_base/SDKs/current"
  '';
}
