{ rustPlatform, fetchFromGitHub, lib }:

rustPlatform.buildRustPackage {
  pname = "srl-tui";
  version = "0.8.7";

  src = fetchFromGitHub {
    owner = "kearnsw";
    repo = "srl-tui";
    rev = "v0.8.7";
    hash = "sha256-nLwfu/woz//1qyAtu9g26n6ats5o6XOZ+In5t/AQTH4=";
  };

  cargoHash = "sha256-S+Y0Dh4a0Pmg/YmDhQ6o3g01jPrTkZWakFSOe+newRg=";

  meta = {
    description = "Spaced repetition flashcard TUI with SM-2 algorithm";
    homepage = "https://github.com/kearnsw/srl-tui";
    license = lib.licenses.mit;
    mainProgram = "srl";
  };
}
