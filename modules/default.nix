{ pkgs, ... }:

# Single platform-selection point for the whole module tree.
#
#   common/         -> every platform (x86_64-linux, aarch64-linux, aarch64-darwin)
#   linux/          -> x86_64-linux + aarch64-linux
#   linux-aarch64/  -> aarch64-linux only (Raspberry Pi 5 hardware)
#   darwin/         -> aarch64-darwin (Apple Silicon)
#
# Home Manager evaluates on the host, so only the matching layer(s) are built.
# `pkgs` is passed via extraSpecialArgs so it is available during `imports`
# evaluation; `pkgs.lib` avoids depending on the `lib` module argument here.
{
  imports =
    [ ./common ]
    ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux ./linux
    ++ pkgs.lib.optional (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64) ./linux-aarch64
    ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isDarwin ./darwin;
}
