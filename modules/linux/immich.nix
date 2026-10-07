{ ... }:

# Linux (x86_64 + aarch64): bind-mount the host timezone into the server.
{
  services.immich.mountLocaltime = true;
}
