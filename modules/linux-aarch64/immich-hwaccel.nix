{ ... }:

# Raspberry Pi 5: pass the V4L2 HEVC decoder through and enable HW transcoding.
{
  services.immich.hardwareAcceleration = true;
  services.immich.devices = [ "/dev/video19:/dev/video19" ];
}
