{
  lib,
  stdenv,
  fetchzip,
  python3,
  fetchPypi,
  nodejs_22,
  buildNpmPackage,
  runCommand,
  autoPatchelfHook,
  zlib,
  libpng,
  glib,
  pixman,
  SDL2,
  libx11,
}:

let
  version = "4.33.1";

  # SDK core is platform independent; the toolchain is not.
  sdkCoreHash = "sha256-hD8XMT0Enc54EGp5yD5sXiKLRaTQ7GFQNeqRL+ZJ6c0=";

  toolchain = {
    aarch64-darwin = {
      url = "https://sdk.repebble.com/releases/${version}/toolchain-mac-arm64.tar.gz";
      hash = "sha256-4KcQTJr9nrm97ZEgwbu5rxenWeizNMnI7C4tFbiQpaM=";
    };
    x86_64-darwin = {
      url = "https://sdk.repebble.com/releases/${version}/toolchain-mac-x86_64.tar.gz";
      hash = "sha256-Vjw++ijNQTNcHd4UYgi8iudn9qG6CG3qNP+uM8xIXZM=";
    };
    x86_64-linux = {
      url = "https://sdk.repebble.com/releases/${version}/toolchain-linux-x86_64.tar.gz";
      hash = "sha256-lJgmri289HETYfJkwywCdJ1V/yD8WSItLq7Apvc0j1k=";
    };
  }.${stdenv.hostPlatform.system} or (throw "pebble-sdk: unsupported system ${stdenv.hostPlatform.system}");

  sdkCore = fetchzip {
    url = "https://sdk.repebble.com/releases/${version}/sdk-core.tar.gz";
    hash = sdkCoreHash;
    stripRoot = false;
  };

  toolchainSrc = fetchzip {
    inherit (toolchain) url hash;
    stripRoot = false;
  };

  # SDK resource tooling calls Reader.asRGBA8(); nixpkgs' newer pypng removed it.
  sdkPython = python3.override {
    packageOverrides = final: prev: {
      pypng = prev.pypng.overrideAttrs (old: {
        version = "0.20220715.0";
        src = fetchPypi {
          pname = "pypng";
          version = "0.20220715.0";
          hash = "sha256-c5xDO6lvB4MV3lTA25da7lN8vD4dCuTtmqsMoeQn4sE=";
        };
        patches = [];
        doCheck = false;
        dontCheck = true;
        checkPhase = "true";
        pytestCheckPhase = "true";
        pythonImportsCheck = [ "png" ];
      });
    };
  };

  pythonEnv = sdkPython.withPackages (
    ps: with ps; [
      freetype-py
      pypng
      sh
      packaging
      setuptools
    ]
  );

  # pebble-tool sets PYTHONHOME=<sdk>/.venv and runs <sdk>/.venv/bin/python.
  # This is a real Python prefix with the SDK's requirements, shaped like a venv.
  sdkVenv = runCommand "pebble-sdk-venv" { } ''
    mkdir -p $out/bin
    ln -s ${pythonEnv}/bin/python3 $out/bin/python
    ln -s ${pythonEnv}/bin/python3 $out/bin/python3
    ln -s ${pythonEnv}/lib $out/lib
    ln -s ${pythonEnv}/include $out/include
  '';

  nodeDeps = buildNpmPackage {
    pname = "pebble-sdk-node-deps";
    inherit version;
    nodejs = nodejs_22;
    src = ./node;
    npmDepsHash = "sha256-ek2P1m3VZW1b46rZZp8wO8TiZTtMZRn1FIWwjJ5qhNM=";
    npmFlags = [ "--legacy-peer-deps" ];
    dontNpmBuild = true;
    NODE_OPTIONS = "--openssl-legacy-provider";
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      cp -r node_modules $out/lib/node_modules
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "pebble-sdk";
  inherit version;

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
    libpng
    glib
    pixman
    SDL2
    libx11
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/sdk-core $out/toolchain
    cp -r ${sdkCore}/sdk-core/. $out/sdk-core/
    cp -r ${toolchainSrc}/toolchain-*/. $out/toolchain/
    chmod -R u+w $out/toolchain
    chmod +x $out/toolchain/bin/qemu-pebble $out/toolchain/moddable-tools/mcrun 2>/dev/null || true
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      ln -s ${libpng}/lib/libpng16.16.dylib $out/toolchain/lib/libpng16.16.dylib
    ''}
    ln -s ${sdkVenv} $out/.venv
    ln -s ${nodeDeps}/lib/node_modules $out/node_modules
    runHook postInstall
  '';

  meta = with lib; {
    description = "Pebble SDK ${version} (SDK core, toolchain, QEMU and Moddable tools)";
    homepage = "https://developer.repebble.com/sdk/";
    license = licenses.asl20;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "pebble-sdk";
  };
}
