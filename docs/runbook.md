# Operations runbook

## Connect and run a health check

```bash
ssh -i ~/.ssh/vpn_ed25519 vpnadmin@<SERVER_IP>
sudo /usr/local/sbin/x-ui-diagnose
```

On Windows, use `$env:USERPROFILE\.ssh\vpn_ed25519` as the key path.

## Service status

```bash
sudo systemctl status x-ui --no-pager
sudo systemctl status x-ui-health --no-pager
sudo systemctl status fail2ban --no-pager
sudo systemctl list-timers 'x-ui-*'
sudo journalctl -u x-ui -u x-ui-health --since '-24 hours' --no-pager
```

`x-ui` owns the panel and Xray process. `x-ui-health` listens only on `127.0.0.1:10809`; the built-in monitor uses it to make a real request through the public Hysteria2 path.

## Add or disable a person

In the `hysteria2-primary` inbound:

1. Add a client with a unique name, generated authentication value, and subscription ID.
2. Apply a traffic or expiry limit only when needed.
3. Test the normal `SUB` URL in OneXray.
4. Send only that person's subscription URL through a private channel.
5. To revoke access, disable or delete that client without changing other users.

Never reuse the technical `health-monitor` client for a person.

## Update 3x-ui

1. Read the target release notes in the official repository.
2. Create and copy a backup off the VPS.
3. Install an explicit stable version; never use `dev-latest` for an unattended upgrade.
4. Run the diagnostic and test one real client.

```bash
sudo /usr/local/sbin/x-ui-backup
sudo bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh) <STABLE_VERSION>
sudo /usr/local/sbin/x-ui-diagnose
```

If the update fails, restore the backup. Do not downgrade only the binary when the database format may also have changed.

## Logs and privacy

The normal configuration keeps warning/error logs and service lifecycle events. Do not leave verbose access or DNS logging enabled permanently.

For a short diagnostic window:

1. enable the required Xray access logging in the panel;
2. reproduce one problem;
3. inspect only the relevant timestamps;
4. disable detailed logging again;
5. remove exported logs after the investigation.

Log rotation keeps `/var/log/x-ui/*.log` for seven rotations. Never paste complete logs publicly without removing URLs, UUIDs, IPs, and tokens.

## Certificate checks

```bash
sudo systemctl status x-ui-cert-renew.timer --no-pager
sudo journalctl -u x-ui-cert-renew.service --since '-7 days' --no-pager
sudo /root/.acme.sh/acme.sh --list
sudo /usr/local/sbin/x-ui-renew-certificate
sudo /usr/local/sbin/x-ui-diagnose
```

The renewal command must print `Certificate renewal check passed`. A successful empty `acme.sh --cron` run is not sufficient: the identity must appear in `acme.sh --list`, the certificate and key must match, and the panel must serve that same certificate.

Public-IP certificates last about six days and normally renew inside the CA-provided renewal window. The systemd timer checks every six hours. If renewal state disappears or less than 48 hours remain, the repository script reissues and reinstalls the certificate automatically.

If the certificate changes location, update `VPN_CERTIFICATE_FILE` and `VPN_CERTIFICATE_KEY_FILE` in `/etc/default/vpn`, then update the panel, subscription, and Hysteria2 TLS settings before restarting 3x-ui.

## Security review

Review these controls after installation and after major upgrades:

```bash
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|kbdinteractiveauthentication|x11forwarding|allowusers|maxauthtries|logingracetime'
sudo ufw status verbose
sudo fail2ban-client status
sudo systemctl --failed
sudo stat -c '%U:%G %a %n' /etc/x-ui/x-ui.db /etc/x-ui/health-client.env
```

In the panel, confirm that TOTP 2FA is enabled, LDAP is disabled unless deliberately used, the administrator username and password are unique, and no unused API tokens remain. Restrict the panel firewall rule with `PANEL_ALLOWED_CIDR` when the administrator has a stable public address.

## When clients cannot connect

1. Run `x-ui-diagnose`.
2. Confirm that the configured tunnel port is listening on UDP and is allowed by both UFW and the provider firewall.
3. Confirm the client selected Hysteria2 with OneXray Routing set to `Global`.
4. Refresh the subscription and test both Wi-Fi and mobile data.
5. Compare the exact failure time with Xray, health-client, and OneXray Error Log entries.
6. Confirm that TLS server name, certificate, client authentication, and Salamander password still match.

If one network fails while another works, the VPS may be healthy and the network path may be filtered.

Use [OneXray troubleshooting](onexray.md) for the end-user steps. Do not interpret a green Online badge as proof that DNS and web traffic work; the egress-IP request is the complete check.
