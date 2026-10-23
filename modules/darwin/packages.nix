{ pkgs, ... }:

# macOS-only packages. Cross-platform tools live in modules/common/packages.nix;
# keep this list for things that build on (or are only wanted on) Apple Silicon.
{
  home.packages = with pkgs; [
    # Qt dependencies for building Eden on macOS.
    qt6.qtbase
    qt6.qtcharts

    # FFmpeg development outputs for linking Eden against the system FFmpeg.
    ffmpeg.dev
    ffmpeg.lib

    # Shader compilation tools used by the build.
    glslang
    spirv-tools
    zstd
    zstd.dev
  ];
}
