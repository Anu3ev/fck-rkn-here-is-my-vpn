# fck-rkn-here-is-my-vpn

This repository is a reproducible, security-focused template for running a small personal VPN on one Ubuntu VPS. It installs 3x-ui and Xray, prepares a VLESS REALITY deployment, hardens the host, and adds health checks, backups, diagnostics, and recovery tooling.

It is designed for a few trusted users, not for a commercial VPN service or a multi-node platform.

## What it provides

- Ubuntu 24.04 LTS on an x86-64 VPS.
- A pinned stable 3x-ui release with its bundled Xray core.
- One recommended VLESS + REALITY + TCP + XTLS Vision inbound.
- A separate UUID and subscription ID for every person.
- An optional technical client that verifies the complete VPN path every 30 seconds.
- UFW, Fail2Ban, SSH key authentication, and unattended security updates.
- Daily SQLite-aware backups with SHA-256 checksums and a safe restore dry run.
- English operator documentation and simple end-user guides.

The tested release is `3x-ui v3.6.0`. Check the [official 3x-ui releases](https://github.com/MHSanaei/3x-ui/releases) before changing the pinned version. Do not substitute `dev-latest` without validating it separately.

## Supported computers

The VPS itself must run Ubuntu 24.04 LTS x86-64. You can administer it from either:

- [Windows 10 or 11 with PowerShell and OpenSSH](docs/install-from-windows.md);
- [Ubuntu Linux](docs/install-from-ubuntu.md).

Both paths create the same server. Only the local SSH and file-copy commands differ.

## Installation flow

1. Read the [preflight checklist](docs/preflight.md).
2. Follow the guide for [Windows](docs/install-from-windows.md) or [Ubuntu](docs/install-from-ubuntu.md).
3. Complete the common [3x-ui and VLESS REALITY configuration](docs/configure-3x-ui.md).
4. Run the [validation checklist](docs/validation.md).
5. Give each person only their own subscription link and the matching [client guide](docs/clients.md).

`deploy.sh` has four explicit phases:

```text
prepare            update Ubuntu, create the sudo user, configure UFW and host security
install            install pinned 3x-ui and the operational files
harden-ssh         disable root/password SSH after a separate key login was verified
enable-operations  enable the tunnel health client, backup timer, and certificate timer
```

The phases are intentionally separate. Password SSH is never disabled before an independent key-based login succeeds.

## Runtime configuration

Real deployment values are not stored in Git. The `prepare` phase writes non-secret values to:

```text
/etc/default/vpn
```

Health-client credentials are stored separately as a root-only file:

```text
/etc/x-ui/health-client.env
```

Panel passwords, API tokens, private keys, subscription URLs, and backup archives must remain outside this repository. Use a password manager or the optional local access workflow in [local access storage](docs/local-access.md).

## Operations

After installation, the main commands are:

```bash
sudo /usr/local/sbin/x-ui-diagnose
sudo /usr/local/sbin/x-ui-backup
systemctl list-timers 'x-ui-*'
```

See the [runbook](docs/runbook.md), [backup and restore guide](docs/backup-and-restore.md), and [redeployment guide](docs/redeploy.md).

## Security boundaries

- A public server IP is not a credential, but no real deployment IP is committed here.
- Use random panel credentials, panel path, subscription paths, client UUIDs, and subscription IDs.
- Restrict the panel to an administrative IP with `PANEL_ALLOWED_CIDR` when practical. Otherwise use HTTPS and consider an SSH tunnel.
- Never share one client UUID among multiple people.
- Keep an encrypted backup outside the VPS; an on-server backup does not protect against provider or disk loss.
- This setup reduces routine risk but cannot guarantee availability in a filtered network.

## Repository map

- `deploy.sh` — phased host and 3x-ui deployment.
- `ops/` — systemd, SSH, firewall-adjacent, logging, and diagnostic configuration.
- `scripts/` — backup, restore, health-client rendering, and optional local access display.
- `docs/` — installation, operation, recovery, monitoring, and end-user guides.

The scripts intentionally target one VPS and SQLite. Kubernetes, Prometheus, Grafana, external databases, and permanent secondary nodes are outside this project's scope.
