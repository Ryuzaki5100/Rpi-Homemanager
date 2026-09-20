{ pkgs, lib, config, ... }:

let
  inherit (config.host) isRpi;

  # The Pi 5 exposes a V4L2 HEVC decoder at /dev/video19. On x86 there is no
  # such device, and passing a missing device makes Docker refuse to start the
  # container, so only the Pi gets the passthrough.
  devicesBlock = lib.optionalString isRpi "    devices:\n      - /dev/video19:/dev/video19\n";

  hwAccelEnabled = if isRpi then "true" else "false";
  hwAccelComment =
    if isRpi then
      "# Hardware acceleration (Pi 5 V4L2 HEVC decoder)"
    else
      "# Hardware acceleration disabled (no V4L2 device passthrough on x86)";
in
{
  xdg.configFile."immich/docker-compose.yml".text = ''
    name: immich

    services:
      immich-server:
        container_name: immich_server
        image: ghcr.io/immich-app/immich-server:''${IMMICH_VERSION:-release}
        volumes:
          - ''${UPLOAD_LOCATION}:/data
          - /etc/localtime:/etc/localtime:ro
    ${devicesBlock}
        env_file:
          - .env
        ports:
          - '2283:2283'
        depends_on:
          - redis
          - database
        restart: "no"
        healthcheck:
          disable: false
          test: ["CMD-SHELL", "curl -f http://localhost:2283/api/server/ping || exit 1"]
          interval: 60s
          timeout: 10s
          retries: 5
          start_period: 120s

      immich-machine-learning:
        container_name: immich_machine_learning
        image: ghcr.io/immich-app/immich-machine-learning:''${IMMICH_VERSION:-release}
        volumes:
          - model-cache:/cache
        env_file:
          - .env
        restart: "no"
        healthcheck:
          disable: false
          interval: 60s
          timeout: 10s
          retries: 5
          start_period: 120s

      redis:
        container_name: immich_redis
        image: docker.io/valkey/valkey:9-alpine
        healthcheck:
          test: redis-cli ping || exit 1
        restart: "no"

      database:
        container_name: immich_postgres
        image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0
        environment:
          POSTGRES_PASSWORD: ''${DB_PASSWORD}
          POSTGRES_USER: ''${DB_USERNAME}
          POSTGRES_DB: ''${DB_DATABASE_NAME}
          POSTGRES_INITDB_ARGS: '--data-checksums'
        volumes:
          - ''${DB_DATA_LOCATION}:/var/lib/postgresql/data
        shm_size: 128mb
        restart: "no"
        healthcheck:
          disable: false

    volumes:
      model-cache:
  '';

  xdg.configFile."immich/.env".text = ''
    # Documentation: https://docs.immich.app/install/environment-variables

    # Photo/video storage location
    UPLOAD_LOCATION=${config.home.homeDirectory}/immich/library

    # Database storage location (no network mounts)
    DB_DATA_LOCATION=${config.home.homeDirectory}/immich/postgres

    # Timezone
    TZ=Asia/Kolkata

    # Immich version (pin to specific version if needed)
    IMMICH_VERSION=v3

    ${hwAccelComment}
    IMMICH_HW_ACCEL_ENABLED=${hwAccelEnabled}

    # Postgres password (local auth only, not exposed)
    DB_PASSWORD=immichpostgres

    # Do not change below this line
    DB_USERNAME=postgres
    DB_DATABASE_NAME=immich
  '';

  home.activation.createImmichDirs = ''
    mkdir -p ~/immich/postgres
    for dir in profile thumbs upload library backups encoded-video; do
      touch ~/immich/library/$dir/.immich 2>/dev/null || true
    done
  '';
}
