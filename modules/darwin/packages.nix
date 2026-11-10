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

    # .NET 10 SDK: switch2mac's shader translator (dmsh_xlate) is a .NET apphost
    # and needs a 10.x runtime. nixpkgs' dotnet sits outside the paths
    # switch2mac.py probes (/usr/local/share/dotnet, /opt/homebrew/opt/dotnet,
    # ~/.dotnet), so DOTNET_ROOT is pointed at it explicitly below.
    dotnet-sdk_10
  ];

  home.sessionVariables.DOTNET_ROOT = "${pkgs.dotnet-sdk_10}/share/dotnet";
}
