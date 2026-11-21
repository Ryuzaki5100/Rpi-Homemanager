{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs_24,
  makeWrapper,
  jetbrains-mono,
  source-sans,
}:

let
  version = "0.7.0";

  isDarwin = stdenv.hostPlatform.isDarwin;

  upstream = fetchFromGitHub {
    owner = "amosblomqvist";
    repo = "learnharness";
    rev = "v${version}";
    hash = "sha256-vToGcCDA1wFKDOUZANqyWoEZLL43c+n62KLzPZ+ZKrc=";
  };

  # Core plugin projects are independent npm projects (the app's npm ci does
  # not install them). Each one gets its own fixed dependency cache so the
  # build stays offline and reproducible.
  pluginDeps = {
    flashcards = fetchNpmDeps {
      name = "learnharness-flashcards-npm-deps";
      src = "${upstream}/plugins/flashcards";
      hash = "sha256-AGjSn0TFK8jx3VpgAROg9fjhZ7gT6CKBD6vr+FbZJKE=";
    };
    coding-questions = fetchNpmDeps {
      name = "learnharness-coding-questions-npm-deps";
      src = "${upstream}/plugins/coding-questions";
      hash = "sha256-qge3Z50q70bjCRgYAnSezG3Jx4y64wvJYepp7511hAM=";
    };
    drawing-pad = fetchNpmDeps {
      name = "learnharness-drawing-pad-npm-deps";
      src = "${upstream}/plugins/drawing-pad";
      hash = "sha256-SbiwseLd9dhSBNDTbr9jfbr6zruoYH5pXUSb2I6roJY=";
    };
    rich-code-blocks = fetchNpmDeps {
      name = "learnharness-rich-code-blocks-npm-deps";
      src = "${upstream}/plugins/rich-code-blocks";
      hash = "sha256-2wt84ICmHf7YywZzLQRVswMBg99OAp43nnt9tJZcupw=";
    };
    ui-showcase = fetchNpmDeps {
      name = "learnharness-ui-showcase-npm-deps";
      src = "${upstream}/plugins/ui-showcase";
      hash = "sha256-1Y1dMZIsM/EmInSd5HOFojDNHLAqrhn68bdON5V4Czw=";
    };
  };

  # The plugin API SDK is generated from the app's own type declarations
  # before npm ci can link the file: dependency.
  pluginSdk = {
    flashcards = false;
    coding-questions = true;
    drawing-pad = true;
    rich-code-blocks = true;
    ui-showcase = true;
  };

  # ui-showcase is not a core plugin, but Next's build type-checks every
  # project under plugins/ and the authoring bundle references its source.
  installPlugins = lib.concatMapStringsSep "\n" (id: ''
    cache="$TMPDIR/npm-cache-${id}"
    cp -R ${pluginDeps.${id}} "$cache"
    chmod -R u+w "$cache"
    ${lib.optionalString pluginSdk.${id} ''
      node scripts/build-plugin-types.mjs "plugins/${id}/.sdk"
    ''}
    (
      cd "plugins/${id}"
      npm_config_cache="$cache" npm_config_offline=true \
        npm ci --ignore-scripts --no-audit --no-fund
    )
  '') [ "flashcards" "coding-questions" "drawing-pad" "rich-code-blocks" "ui-showcase" ];

  # The app is a Next.js standalone server; the Electron shell is not built.
  # Keys stay in the app profile; learning records live wherever LH_DATA_DIR
  # points (the dotfiles module points it at the synced data repository).
  authDir = if isDarwin then "Library/Application Support/LearnHarness" else ".config/LearnHarness";

  launcher = ''
    #!/bin/sh
    set -eu

    DATA_DIR="''${LH_DATA_DIR:-$HOME/learning/learnharness-data}"
    AUTH_FILE="''${LH_AUTH_FILE:-$HOME/${authDir}/auth.json}"
    PORT="''${PORT:-4747}"
    # HOSTNAME is normally the machine name, so it cannot double as the bind
    # address. LH_HOST is the deliberate override (e.g. 0.0.0.0 behind a
    # tailnet), and HOSTNAME is what Next's standalone server actually reads.
    BIND="''${LH_HOST:-127.0.0.1}"

    export LH_DATA_DIR="$DATA_DIR"
    export LH_AUTH_FILE="$AUTH_FILE"
    export HOSTNAME="$BIND"
    export PORT="$PORT"
    mkdir -p "$DATA_DIR" "$(dirname "$AUTH_FILE")"

    if command -v lh-sync >/dev/null 2>&1; then
      if ! lh-sync pull; then
        echo "learnharness: refusing to start — lh-sync pull did not complete" >&2
        exit 1
      fi
    fi

    echo "learnharness: serving http://$BIND:$PORT (data: $DATA_DIR)"
    node @out@/share/learnharness/server.js &
    child=$!

    stop() {
      kill "$child" 2>/dev/null || true
      wait "$child" 2>/dev/null || true
      if command -v lh-sync >/dev/null 2>&1; then
        lh-sync push || true
      fi
    }
    trap stop INT TERM HUP

    if [ "''${LEARNHARNESS_OPEN:-0}" = "1" ]; then
      i=0
      while [ $i -lt 40 ]; do
        if curl -fsS "http://$BIND:$PORT/api/chats" >/dev/null 2>&1; then
          break
        fi
        i=$((i + 1))
        sleep 0.25
      done
      open "http://$BIND:$PORT"
    fi

    wait "$child"
    status=$?
    trap - INT TERM HUP
    stop
    exit $status
  '';
in
buildNpmPackage {
  pname = "learnharness";
  inherit version;

  src = upstream;

  npmDepsHash = "sha256-ink0rVziD1xk3dVq9ORWXIe03ISSlpDuBfXtzDBBNbA=";

  nodejs = nodejs_24;

  nativeBuildInputs = [ makeWrapper ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PUPPETEER_SKIP_DOWNLOAD = "1";
    NEXT_TELEMETRY_DISABLED = "1";
    NODE_OPTIONS = "--max-old-space-size=4096";
  };

  # next/font/google would fetch fonts at build time. Replace it with the
  # same OFL families served from public/fonts, keeping the CSS variables the
  # theme consumes.
  postPatch = ''
    mkdir -p public/fonts
    cp '${jetbrains-mono}/share/fonts/truetype/JetBrainsMono[wght].ttf' public/fonts/JetBrainsMono-wght.ttf
    cp '${jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Italic[wght].ttf' public/fonts/JetBrainsMono-Italic-wght.ttf
    cp '${source-sans}/share/fonts/truetype/SourceSans3-Regular.ttf' public/fonts/SourceSans3-Regular.ttf
    cp '${source-sans}/share/fonts/truetype/SourceSans3-It.ttf' public/fonts/SourceSans3-It.ttf
    cp '${source-sans}/share/fonts/truetype/SourceSans3-Semibold.ttf' public/fonts/SourceSans3-SemiBold.ttf
    cp '${source-sans}/share/fonts/truetype/SourceSans3-Bold.ttf' public/fonts/SourceSans3-Bold.ttf
    chmod -R u+w public/fonts

    substituteInPlace app/layout.tsx \
      --replace-fail 'import { JetBrains_Mono, Source_Sans_3 } from "next/font/google";' '// Offline build: the same OFL families are served from public/fonts.' \
      --replace-fail 'const ui = JetBrains_Mono({ subsets: ["latin"], variable: "--font-jetbrains" });' '// --font-jetbrains is defined in globals.css for offline builds.' \
      --replace-fail 'const prose = Source_Sans_3({ subsets: ["latin"], variable: "--font-sans3" });' '// --font-sans3 is defined in globals.css for offline builds.' \
      --replace-fail 'className={`''${theme.mode} ''${ui.variable} ''${prose.variable}`}' 'className={theme.mode}'

    cat >> app/globals.css <<'EOF'

/* Offline font faces: this build serves the same OFL families from
   public/fonts instead of next/font/google. */
@font-face {
  font-family: "JetBrains Mono";
  src: url("/fonts/JetBrainsMono-wght.ttf") format("truetype");
  font-weight: 100 800;
  font-style: normal;
  font-display: swap;
}
@font-face {
  font-family: "JetBrains Mono";
  src: url("/fonts/JetBrainsMono-Italic-wght.ttf") format("truetype");
  font-weight: 100 800;
  font-style: italic;
  font-display: swap;
}
@font-face {
  font-family: "Source Sans 3";
  src: url("/fonts/SourceSans3-Regular.ttf") format("truetype");
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}
@font-face {
  font-family: "Source Sans 3";
  src: url("/fonts/SourceSans3-It.ttf") format("truetype");
  font-weight: 400;
  font-style: italic;
  font-display: swap;
}
@font-face {
  font-family: "Source Sans 3";
  src: url("/fonts/SourceSans3-SemiBold.ttf") format("truetype");
  font-weight: 600;
  font-style: normal;
  font-display: swap;
}
@font-face {
  font-family: "Source Sans 3";
  src: url("/fonts/SourceSans3-Bold.ttf") format("truetype");
  font-weight: 700;
  font-style: normal;
  font-display: swap;
}
:root {
  --font-jetbrains: "JetBrains Mono";
  --font-sans3: "Source Sans 3";
}
EOF
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    ${installPlugins}
    npm run plugins:build-core
    npm run plugins:build-authoring
    node node_modules/next/dist/bin/next build
    node scripts/build-server.mjs

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/learnharness $out/bin
    cp -R .next/standalone/. $out/share/learnharness/
    # The traced payload may already contain skills/; replace it rather than
    # nesting a second copy inside it.
    rm -rf $out/share/learnharness/skills/learnharness
    mkdir -p $out/share/learnharness/skills
    cp -R skills/learnharness $out/share/learnharness/skills/learnharness

    cat > $out/bin/learnharness <<'LAUNCHER'
    ${launcher}
    LAUNCHER
    chmod +x $out/bin/learnharness
    substituteInPlace $out/bin/learnharness --replace-fail '@out@' "$out"

    ${lib.optionalString isDarwin ''
      app="$out/Applications/LearnHarness.app"
      mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
      cp build/icon.icns "$app/Contents/Resources/icon.icns"
      cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>LearnHarness</string>
  <key>CFBundleIdentifier</key><string>ai.learnharness.desktop</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>LearnHarness</string>
  <key>CFBundleDisplayName</key><string>LearnHarness</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleVersion</key><string>${version}</string>
  <key>CFBundleIconFile</key><string>icon.icns</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
      cat > "$app/Contents/MacOS/LearnHarness" <<APP
#!/bin/sh
export LEARNHARNESS_OPEN=1
exec "$out/bin/learnharness"
APP
      chmod +x "$app/Contents/MacOS/LearnHarness"
    ''}

    runHook postInstall
  '';

  doInstallCheck = false;

  meta = {
    description = "Agent harness for learning: adaptive teaching, practice, and a knowledge graph";
    homepage = "https://learnharness.ai";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.unix;
    mainProgram = "learnharness";
  };
}
