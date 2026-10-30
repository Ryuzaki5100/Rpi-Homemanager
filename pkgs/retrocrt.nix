{ lib, python3, writeShellScriptBin, ffmpeg, dejavu_fonts }:

let
  pythonEnv = python3.withPackages (ps: [ ps.pillow ]);
  scriptPath = ../scripts/retrocrt.py;
in
writeShellScriptBin "retrocrt" ''
  export RETROCRT_FFMPEG="${ffmpeg}/bin/ffmpeg"
  export RETROCRT_FFPROBE="${ffmpeg}/bin/ffprobe"
  export RETROCRT_FONT="${dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf"
  exec ${pythonEnv}/bin/python3 "${scriptPath}" "$@"
''
