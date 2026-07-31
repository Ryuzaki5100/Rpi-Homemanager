COMPOSE := docker compose -f $(HOME)/.config/immich/docker-compose.yml
IMMICH_DIR := $(HOME)/.config/immich
BACKUP_DIR := $(HOME)/immich/backups

.PHONY: help immich-setup immich-teardown immich-start immich-stop immich-shutdown immich-restart immich-pull immich-update immich-logs immich-logs-server immich-logs-ml immich-logs-postgres immich-logs-redis immich-status immich-exec immich-db-shell immich-sync immich-backup immich-restore immich-clean immich-prune immich-ip immich-check-hdd immich-hdd-mount immich-hdd-unmount immich-hdd-status immich-link-library

help:
	@echo "Usage: make immich-<target>"
	@echo ""
	@echo "Setup:"
	@echo "  immich-setup            - First-time setup (start daemon, create dirs, pull, start Immich)"
	@echo "  immich-teardown         - Stop and remove all containers and volumes"
	@echo "  immich-link-library     - Create symlink ~/immich/library -> /mnt/hdd/immich/library"
	@echo ""
	@echo "Lifecycle:"
	@echo "  immich-start            - Start Docker daemon + Immich containers (auto-mounts /mnt/hdd)"
	@echo "  immich-stop             - Stop Immich containers (daemon stays running)"
	@echo "  immich-shutdown         - Stop containers AND Docker daemon (full power-off)"
	@echo "  immich-restart          - Restart Immich containers"
	@echo "  immich-pull             - Pull latest images"
	@echo "  immich-update           - Pull latest images and restart"
	@echo ""
	@echo "Debug:"
	@echo "  immich-logs             - Tail container logs"
	@echo "  immich-logs-server      - Tail logs for the Immich server"
	@echo "  immich-logs-ml          - Tail logs for machine learning"
	@echo "  immich-logs-postgres    - Tail logs for PostgreSQL"
	@echo "  immich-logs-redis       - Tail logs for Redis"
	@echo "  immich-status           - Show container status"
	@echo "  immich-exec             - Open a shell in the Immich server container"
	@echo "  immich-db-shell         - Open a psql shell in the database"
	@echo ""
	@echo "HDD:"
	@echo "  immich-hdd-mount        - Mount /mnt/hdd (auto-recovers stale mounts)"
	@echo "  immich-hdd-unmount      - Safely unmount /mnt/hdd"
	@echo "  immich-hdd-status       - Show mount status and disk info"
	@echo ""
	@echo "Sync & Backup:"
	@echo "  immich-sync DEST=DIR    - Sync all albums to DIR (organized by album name)"
	@echo "  immich-backup           - Dump the database to ~/immich/backups/"
	@echo "  immich-restore          - Restore the database from the latest backup"
	@echo ""
	@echo "Maintenance:"
	@echo "  immich-clean            - Remove stopped containers and dangling images"
	@echo "  immich-prune            - Remove all unused Docker data (images, networks, volumes)"
	@echo ""
	@echo "  immich-ip               - Print the Immich access URL"

# --- Helpers ---

immich-check-hdd:
	@mountpoint -q /mnt/hdd || { echo "ERROR: /mnt/hdd is not mounted. Insert the HDD and run: sudo mount /mnt/hdd"; exit 1; }

HDD_UUID := 7B6D-F242

immich-hdd-mount:
	@CUR=$$(lsblk -o UUID,NAME -rn /dev/sd* 2>/dev/null | awk -v u="$(HDD_UUID)" '$$1==u{print "/dev/"$$2}' | head -1); \
	if [ -z "$$CUR" ]; then \
		echo "ERROR: HDD (UUID $(HDD_UUID)) not detected on USB. Check the cable/power and reconnect it."; \
		echo "  Diagnostics: sudo dmesg | grep -i usb"; \
		exit 1; \
	fi; \
	SRC=$$(findmnt -no SOURCE /mnt/hdd 2>/dev/null || true); \
	if [ -n "$$SRC" ] && [ "$$SRC" = "$$CUR" ]; then \
		echo "==> /mnt/hdd already mounted ($$SRC)"; \
	elif [ -n "$$SRC" ]; then \
		echo "==> Stale mount detected ($$SRC -> $$CUR); remounting..."; \
		sudo umount /mnt/hdd 2>/dev/null || sudo umount -l /mnt/hdd; \
		sudo mount /mnt/hdd; \
		echo "==> Mounted /mnt/hdd"; \
	else \
		sudo mount /mnt/hdd; \
		echo "==> Mounted /mnt/hdd"; \
	fi

immich-hdd-unmount:
	@if mountpoint -q /mnt/hdd; then \
		sudo umount /mnt/hdd; \
		echo "==> /mnt/hdd unmounted"; \
	else \
		echo "/mnt/hdd is not mounted"; \
	fi

immich-hdd-status:
	@if mountpoint -q /mnt/hdd; then \
		echo "==> /mnt/hdd: MOUNTED"; \
	else \
		echo "==> /mnt/hdd: NOT mounted"; \
	fi
	@lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT /dev/sd* 2>/dev/null || echo "No USB block devices detected"

immich-link-library:
	@if [ -L ~/immich/library ]; then \
		echo "==> Symlink already exists: ~/immich/library -> $$(readlink ~/immich/library)"; \
	elif [ -d ~/immich/library ]; then \
		echo "ERROR: ~/immich/library is a directory (old data?). Remove it first:"; \
		echo "  rm -rf ~/immich/library"; \
		exit 1; \
	else \
		ln -s /mnt/hdd/immich/library ~/immich/library; \
		echo "==> Created symlink: ~/immich/library -> /mnt/hdd/immich/library"; \
	fi

# --- Setup ---

immich-setup: immich-hdd-mount immich-link-library
	@echo "==> Starting Docker daemon..."
	@sudo systemctl start docker
	@echo "==> Creating Immich directories..."
	@mkdir -p $(HOME)/immich/postgres $(BACKUP_DIR)
	@echo "==> Pulling latest images..."
	@sg docker -c "$(COMPOSE) pull"
	@echo "==> Starting Immich..."
	@sg docker -c "$(COMPOSE) up -d"
	@echo ""
	@echo "==> Immich is running at: http://$$(hostname -I | awk '{print $$1}'):2283"

immich-teardown:
	@echo "==> Stopping and removing containers + volumes..."
	@sg docker -c "$(COMPOSE) down -v"

# --- Lifecycle ---

immich-start: immich-hdd-mount
	@sudo systemctl start docker
	@sg docker -c "$(COMPOSE) up -d"

immich-stop:
	sg docker -c "$(COMPOSE) down"

immich-shutdown: immich-stop
	@sudo systemctl stop docker
	@echo "==> Docker daemon stopped"

immich-restart:
	sg docker -c "$(COMPOSE) restart"

immich-pull:
	sg docker -c "$(COMPOSE) pull"

immich-update: immich-pull immich-restart

# --- Debug ---

immich-logs:
	sg docker -c "$(COMPOSE) logs -f"

immich-logs-server:
	sg docker -c "$(COMPOSE) logs -f immich_server"

immich-logs-ml:
	sg docker -c "$(COMPOSE) logs -f immich_machine_learning"

immich-logs-postgres:
	sg docker -c "$(COMPOSE) logs -f immich_postgres"

immich-logs-redis:
	sg docker -c "$(COMPOSE) logs -f immich_redis"

immich-status:
	sg docker -c "$(COMPOSE) ps"

immich-exec:
	sg docker -c "$(COMPOSE) exec immich_server bash"

immich-db-shell:
	sg docker -c "$(COMPOSE) exec immich_postgres psql -U postgres -d immich"

# --- Sync & Backup ---

immich-sync: immich-hdd-mount
	bash $(HOME)/dotfiles/scripts/sync-to-ssd.sh "$(DEST)"

immich-backup:
	@mkdir -p $(BACKUP_DIR)
	@echo "==> Dumping database..."
	@sg docker -c "$(COMPOSE) exec -T immich_postgres pg_dump -U postgres immich" | gzip > $(BACKUP_DIR)/immich-$(shell date +%Y%m%d-%H%M%S).sql.gz
	@echo "==> Backup saved to $(BACKUP_DIR)/"
	@ls -lh $(BACKUP_DIR)/immich-$(shell date +%Y%m%d)*

immich-restore:
	@LATEST=$$(ls -t $(BACKUP_DIR)/immich-*.sql.gz 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then echo "No backup found in $(BACKUP_DIR)/"; exit 1; fi; \
	echo "==> Restoring from $$LATEST..."; \
	gunzip -c "$$LATEST" | sg docker -c "$(COMPOSE) exec -T immich_postgres psql -U postgres immich"; \
	echo "==> Restore complete"

# --- Maintenance ---

immich-clean:
	@sg docker -c "$(COMPOSE) down --remove-orphans" 2>/dev/null || true
	@sg docker -c "docker image prune -f"

immich-prune:
	@sg docker -c "docker system prune -a --volumes -f"

immich-ip:
	@echo "http://$$(hostname -I | awk '{print $$1}'):2283"
