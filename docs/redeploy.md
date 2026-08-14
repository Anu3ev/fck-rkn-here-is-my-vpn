# Redeploy on a replacement VPS

Use this process when the original VPS is lost, its IP must change, or you want to test disaster recovery. It does not require a permanently running second server.

## 1. Prepare the replacement host

Create a fresh Ubuntu 24.04 x86-64 VPS. Follow the normal [Windows](install-from-windows.md) or [Ubuntu](install-from-ubuntu.md) guide through these phases:

```bash
bash ./deploy.sh prepare
KEY_LOGIN_VERIFIED=verified bash ./deploy.sh harden-ssh
bash ./deploy.sh install
```

Do not manually create human clients in the new panel. They will come from the restored SQLite database.

## 2. Upload the latest backup

From Windows PowerShell:

```powershell
scp -i "$env:USERPROFILE\.ssh\vpn_ed25519" `
  <LOCAL_BACKUP_ARCHIVE> `
  vpnadmin@<NEW_SERVER_IP>:/home/vpnadmin/x-ui-restore.tar.gz
```

From Ubuntu:

```bash
scp -i ~/.ssh/vpn_ed25519 \
  <LOCAL_BACKUP_ARCHIVE> \
  vpnadmin@<NEW_SERVER_IP>:/home/vpnadmin/x-ui-restore.tar.gz
```

## 3. Validate and restore

On the new VPS:

```bash
sudo /usr/local/sbin/x-ui-restore --dry-run \
  /home/vpnadmin/x-ui-restore.tar.gz
sudo /usr/local/sbin/x-ui-restore \
  /home/vpnadmin/x-ui-restore.tar.gz
```

The restore includes the old runtime address by design. Update the new deployment values immediately:

```bash
sudoedit /etc/default/vpn
sudo /usr/local/sbin/x-ui-render-health-client
sudo systemctl restart x-ui-health x-ui
```

Change at least `VPN_SERVER_ADDRESS`, `VPN_EXPECTED_EGRESS_IP`, and `VPN_TLS_SERVER_NAME` when the domain changes. Change public ports only when the replacement deployment intentionally uses different ones.

## 4. Update public endpoints

1. Point the VPN domain to the new IP, if a domain is used.
2. Reissue or reinstall the HTTPS certificate.
3. Update the panel, subscription, and Hysteria2 public address and certificate paths in 3x-ui.
4. Verify the random panel and subscription paths were preserved.
5. Refresh each user's subscription in their client.

## 5. Validate before retiring the old host

```bash
sudo /usr/local/sbin/x-ui-diagnose
sudo systemctl --failed
sudo systemctl list-timers 'x-ui-*'
```

Test one real user in OneXray on Wi-Fi and mobile data. Confirm Global routing, external IP, DNS, panel traffic counters, UDP listener, backup timer, and certificate. Remove the uploaded restore archive from the administrative home only after an off-server encrypted copy is safe.
