{
  pkgs,
  ...
}:

{
  # retrocrt: turn a video into a curved-bezel CRT / VHS style clip.
  # The CLI lives in scripts/retrocrt.py; the package pins ffmpeg, the
  # timestamp font, and a Python env with Pillow.
  home.packages = [ pkgs.retrocrt ];
}
