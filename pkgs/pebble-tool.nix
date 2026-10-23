{ pkgs, pebble, python3Packages, pypkjs }:

(pkgs.callPackage "${pebble}/derivations/pebble-tool.nix" {
  inherit python3Packages pypkjs;
  nodejs = pkgs.nodejs_22;
}).overrideAttrs (old: {
  # pebble-tool 5.0.40 + SDK 4.33.1: the emulator serial banner is not
  # reliably visible on the port the tool waits on. The Pebble protocol port
  # works, so skip the banner wait and let the protocol connection retry.
  # Also force the modern QEMU command line when version detection fails.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace pebble_tool/sdk/emulator.py \
      --replace "qemu_major = get_qemu_version()" "qemu_major = get_qemu_version() or 10" \
      --replace "self._wait_for_qemu()" "time.sleep(3)"
    substituteInPlace pebble_tool/commands/sdk/project/__init__.py \
      --replace "env['PYTHONPATH'] = ':'.join(sys.path)" "env['PYTHONPATH'] = \"\""
  '';
})
