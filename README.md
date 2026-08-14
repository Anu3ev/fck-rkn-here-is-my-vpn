# fck-rkn-here-is-my-vpn

This repository is a reproducible, security-focused template for a small personal VPN on one rented VPS. It installs 3x-ui with Xray, uses one Hysteria2 tunnel over UDP, hardens Ubuntu, and adds end-to-end health checks, backups, diagnostics, and recovery tooling.

It is designed for a few trusted people, not for a commercial VPN service or a multi-node platform.

## What you need

- A fresh Ubuntu 24.04 LTS x86-64 VPS.
- A public IPv4 address.
- A domain with an `A` record pointing to that address.
- A Windows 10/11 or Ubuntu computer for administration.
- About 30-60 minutes for the first deployment.

The domain is required for a valid TLS certificate. The VPS needs at least 1 GB RAM and 10 GB disk for a small deployment.

## What this installs

- The pinned stable `3x-ui v3.6.0` release and its bundled Xray core.
- One recommended Hysteria2 inbound on UDP port `443`.
- TLS 1.3 with `h3` ALPN and Salamander UDP masking.
- A separate authentication value and subscription ID for each person.
- A technical client that tests the complete VPN path every 30 seconds.
- UFW, Fail2Ban, SSH key authentication, and unattended security updates.
- Daily SQLite-aware backups with SHA-256 checksums and a restore dry run.

Check the [official 3x-ui releases](https://github.com/MHSanaei/3x-ui/releases) before changing the pinned version. Do not use `dev-latest` without validating it separately.

## Start here

1. Complete the [preflight checklist](docs/preflight.md).
2. Follow the installation guide for [Windows](docs/install-from-windows.md) or [Ubuntu](docs/install-from-ubuntu.md).
3. Complete the common [3x-ui and Hysteria2 setup](docs/configure-3x-ui.md).
4. Run the [validation checklist](docs/validation.md).
5. Send each person their private link using the [OneXray guide](docs/onexray.md) and [message template](docs/user-message-template.md).

Both administration paths create the same server. Only the local SSH and file-copy commands differ.

## Deployment phases

`deploy.sh` separates changes that must be verified before continuing:

```text
prepare            update Ubuntu, create the sudo user, configure UFW and host security
install            install pinned 3x-ui and the operational files
harden-ssh         disable root/password SSH after a separate key login was verified
enable-operations  enable tunnel health checks, backups, and certificate renewal
```

Password SSH is never disabled before an independent key-based login succeeds.

## Secrets and runtime data

The `prepare` phase writes non-secret deployment values to `/etc/default/vpn`. The technical Hysteria2 client credentials live in the root-only `/etc/x-ui/health-client.env` file.

Panel passwords, private keys, subscription URLs, client authentication values, and backups must remain outside Git. Use a password manager or the optional [local access storage](docs/local-access.md).

## Routine commands

```bash
sudo /usr/local/sbin/x-ui-diagnose
sudo /usr/local/sbin/x-ui-backup
sudo systemctl list-timers 'x-ui-*'
```

See the [operations runbook](docs/runbook.md), [backup and restore guide](docs/backup-and-restore.md), and [redeployment guide](docs/redeploy.md).

An existing server that still uses VLESS should follow the separate [Hysteria2 migration guide](docs/migrate-from-vless.md). It validates one client before the old inbound and TCP rule are removed.

## Security boundaries

- A public server IP is not a credential, but real deployment details do not belong in this template.
- Use random panel credentials, web paths, Hysteria2 authentication values, masking password, and subscription IDs.
- Restrict the panel to an administrative IP with `PANEL_ALLOWED_CIDR` when practical. Otherwise use HTTPS and consider an SSH tunnel.
- Give every person a separate client record and link so one account can be revoked safely.
- Keep an encrypted backup outside the VPS. An on-server backup does not protect against provider or disk loss.
- No protocol or server IP is guaranteed to remain reachable from every filtered network.

## Repository map

- `deploy.sh` — phased host and 3x-ui deployment.
- `ops/` — systemd, SSH, logging, security, and diagnostic configuration.
- `scripts/` — backup, restore, health-client rendering, and local access tools.
- `docs/` — installation, operation, recovery, migration, and end-user guides.

The scripts intentionally target one Ubuntu VPS and SQLite. Kubernetes, external databases, and permanent secondary nodes are outside this project's scope.
