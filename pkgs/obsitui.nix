{ buildNpmPackage, fetchFromGitHub, lib }:

buildNpmPackage {
  name = "obsitui";
  src = fetchFromGitHub {
    owner = "atr0t0s";
    repo = "obsitui";
    rev = "main";
    sha256 = "0sil7lb2xqz8s7wg700wabcgqpdvacrrh7yfg0xkjpzr0bvq4gsg";
  };
  npmDepsHash = "sha256-mAIErsauFMKRbyKpbJjMfiLYvqfJxNeMmK4rtCmI+U4=";
  postInstall = ''
    if [ -d dist ]; then
      mkdir -p "$out/lib/node_modules/obsitui/dist"
      cp -r dist/* "$out/lib/node_modules/obsitui/dist/"
    fi
  '';
  meta = {
    description = "Terminal UI for browsing and editing Obsidian vaults";
    homepage = "https://github.com/atr0t0s/obsitui";
    license = lib.licenses.mit;
  };
}
