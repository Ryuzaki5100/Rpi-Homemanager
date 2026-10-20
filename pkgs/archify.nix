{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  makeWrapper,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "archify";
  version = "3.2.0";

  src = fetchFromGitHub {
    owner = "tt-a1i";
    repo = "archify";
    rev = "208acba8d412335185b2056fedf54b3405df43fb";
    hash = "sha256-pejw78BgKDnttOAGcLvVtWa50azpCjTfESnmdYIjCoI=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/archify" "$out/bin"
    cp -R archify/. "$out/share/archify/"

    makeWrapper ${nodejs}/bin/node "$out/bin/archify" \
      --add-flags "$out/share/archify/bin/archify.mjs" \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --set ARCHIFY_ROOT "$out/share/archify" \
      --set ARCHIFY_UPDATE_CHECK_DISABLED 1

    runHook postInstall
  '';

  meta = {
    description = "Turn content into validated, interactive HTML diagrams";
    homepage = "https://github.com/tt-a1i/archify";
    license = lib.licenses.mit;
    mainProgram = "archify";
  };
})
