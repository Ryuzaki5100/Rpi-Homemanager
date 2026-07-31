{ pkgs, lib, config, ... }:

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

    # Postgres password (local auth only, not exposed)
    DB_PASSWORD=immichpostgres

    # Do not change below this line
    DB_USERNAME=postgres
    DB_DATABASE_NAME=immich
  '';

  home.activation.createImmichDirs = ''
    mkdir -p ~/immich/postgres
  '';
}
