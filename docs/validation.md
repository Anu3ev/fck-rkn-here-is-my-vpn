# Validation checklist

This file is a reusable checklist, not proof that a new deployment has passed. Save real results, dates, IPs, usernames, and screenshots in a private deployment record.

## Host and SSH

- A new `vpnadmin` key login succeeds in a separate SSH session.
- `sudo true` succeeds for the administrative user.
- A second key login succeeds after `harden-ssh`.
- Root SSH, password SSH, and keyboard-interactive SSH are rejected.
- `sshd -t` succeeds.
- UFW is active and exposes only the intended ports.
- Fail2Ban and unattended security updates are active.
- `systemctl --failed` reports no failed units.

## Panel and subscriptions

- The panel uses HTTPS with a valid certificate.
- The panel username, password, port, and web base path are not defaults.
- The subscription, JSON, and Clash paths are random and are not `/sub/`, `/json/`, or `/clash/`.
- An old or deliberately invalid subscription URL returns HTTP 404.
- Each person has a unique UUID and subscription ID.
- Temporary installer or fallback API tokens have been removed.

## VPN path

- One Hysteria2 inbound listens on the configured UDP tunnel port.
- The VPS provider firewall and UFW both allow that UDP port.
- TLS uses the configured domain, a valid certificate, and `h3` ALPN.
- FinalMask uses UDP Salamander with the same strong password on server and clients.
- Every person has a unique authentication value and subscription ID.
- The technical health client is separate from all human users.
- `x-ui-diagnose` reports a successful Hysteria2 HTTPS request and the expected egress IP.
- A real phone or computer imports its subscription, connects, resolves DNS, and shows the VPS egress IP.
- Per-client online state and traffic counters update in 3x-ui.

## Recovery and lifecycle

- `x-ui-backup` creates an archive and checksum.
- `x-ui-restore --dry-run <archive>` succeeds.
- The latest backup has also been copied to encrypted storage outside the VPS.
- 3x-ui, Xray, the health client, Fail2Ban, and timers start after a controlled reboot.
- Certificate expiry is comfortably longer than the renewal interval.

## Commands

```bash
sudo /usr/local/sbin/x-ui-diagnose
sudo systemctl --failed
sudo systemctl list-timers 'x-ui-*'
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|kbdinteractiveauthentication|allowusers|maxauthtries|logingracetime'
sudo /usr/local/sbin/x-ui-backup
```

## Honest limitations

- A successful test from one country or network does not guarantee reachability from another.
- A normal TCP monitor cannot validate a Hysteria2 UDP listener.
- An open UDP port does not prove that TLS, authentication, masking, DNS, and proxying all work.
- A restore dry run validates the archive and SQLite database but does not replace a periodic restore test on a clean VPS.
- No single transport or IP address is guaranteed to remain reachable in a filtered network.
