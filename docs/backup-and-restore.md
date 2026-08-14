# Backup and restore

Backups contain the 3x-ui database, client credentials, certificate private keys, SSH authorized key, firewall rules, and operational configuration. Treat every archive as a secret.

Archives are stored in `/var/backups/x-ui`, retained for 14 days, and accompanied by SHA-256 checksums.

## Create a backup

```bash
sudo /usr/local/sbin/x-ui-backup
sudo systemctl start x-ui-backup.service
sudo journalctl -u x-ui-backup.service -n 50 --no-pager
```

The script uses SQLite's online backup operation and verifies `PRAGMA integrity_check` before building the archive.

## Verify the checksum

```bash
cd /var/backups/x-ui
latest_checksum="$(find . -maxdepth 1 -type f -name 'x-ui-*.tar.gz.sha256' \
  -printf '%T@ %f\n' | sort -nr | awk 'NR == 1 {print $2}')"
sudo sha256sum --check "${latest_checksum}"
```

## Copy a backup off the VPS

From Windows PowerShell:

```powershell
scp -i "$env:USERPROFILE\.ssh\vpn_ed25519" `
  vpnadmin@<SERVER_IP>:/var/backups/x-ui/<ARCHIVE> `
  <ENCRYPTED_LOCAL_BACKUP_FOLDER>
```

The backup directory is root-only by default. Copy the selected archive to the administrative user's home with `sudo install -m 600` first, then remove that temporary copy after `scp` succeeds.

From Ubuntu, use the same flow with `scp -i ~/.ssh/vpn_ed25519`.

## Safe dry run

```bash
sudo /usr/local/sbin/x-ui-restore --dry-run \
  /var/backups/x-ui/x-ui-YYYYMMDDTHHMMSSZ.tar.gz
```

The dry run extracts into a temporary directory, validates the expected structure and runtime configuration, and checks SQLite integrity without stopping services.

## Full restore

```bash
sudo /usr/local/sbin/x-ui-restore \
  /var/backups/x-ui/x-ui-YYYYMMDDTHHMMSSZ.tar.gz
sudo /usr/local/sbin/x-ui-diagnose
```

Before replacing live files, the restore script creates a rescue backup. It restores only the VPN-owned state and the host configuration explicitly listed in the script.

After restoring onto a different IP or domain, update `VPN_SERVER_ADDRESS`, `VPN_EXPECTED_EGRESS_IP`, and `VPN_TLS_SERVER_NAME` in `/etc/default/vpn`. Reissue the certificate, update the Hysteria2 and subscription addresses in 3x-ui, rerender the health client, and refresh user subscriptions.
