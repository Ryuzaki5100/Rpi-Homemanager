{ pkgs, ... }:

# Linux-only packages (no aarch64-darwin build available).
# macOS equivalents: fastfetch (for nitch), native Bluetooth/Wi-Fi, native exFAT.
{
  home.packages = with pkgs; [
    code-server
    nitch
    bluetuith
    wifitui
    exfatprogs
    foliate # GTK/WebKitGTK ebook reader; webkitgtk is broken on aarch64-darwin
  ];
}
