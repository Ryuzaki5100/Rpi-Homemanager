#!/usr/bin/env bash
set -euo pipefail

# Stop the desktop session (udisks2/gvfs) from auto-mounting the Immich HDD
# (My Passport, exFAT, UUID 7B6D-F242) under /media. That auto-mount collides
# with /etc/fstab -> /mnt/hdd and leaves the drive in a read-only state, which
# makes `make immich-hdd-mount` fail with "already mounted or mount point busy".
#
# The udev rule is a hint only: the drive is never auto-mounted, but stays
# visible and manually mountable in the file manager. Mount it with:
#   make immich-hdd-mount

RULE_FILE="/etc/udev/rules.d/99-immich-hdd.rules"
HDD_UUID="7B6D-F242"

echo "=== HDD auto-mount prevention ==="

if [ -f "$RULE_FILE" ] && grep -q "$HDD_UUID" "$RULE_FILE"; then
    echo "udev rule already present ($RULE_FILE); skipping"
else
    echo "Writing $RULE_FILE..."
    sudo tee "$RULE_FILE" > /dev/null <<EOF
# Never auto-mount the Immich HDD ($HDD_UUID) in the desktop session.
# It is managed by /etc/fstab -> /mnt/hdd. Mount it with: make immich-hdd-mount
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$HDD_UUID", ENV{UDISKS_AUTOMOUNT_HINT}="never", ENV{UDISKS_PRESENTATION_NOPOLICY}="1"
# Mount it at /mnt/hdd via systemd whenever it appears (restart clears any stale
# mount left by an abrupt unplug), so it stays accessible (e.g. via sftp).
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$HDD_UUID", RUN+="/usr/bin/systemctl --no-block restart mnt-hdd.mount"
EOF
fi

echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "=== Done ==="
echo "Re-plug the HDD (or run: sudo udevadm trigger), then: make immich-hdd-mount"
