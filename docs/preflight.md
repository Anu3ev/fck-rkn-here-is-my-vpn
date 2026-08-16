# Preflight checklist

Run this checklist before changing a VPS. Stop if the host is not a new, dedicated server or if an existing VPN must be preserved.

## Required inputs

- A fresh Ubuntu 24.04 LTS x86-64 VPS with temporary root SSH access.
- A public IPv4 address.
- Preferably a domain you control, with an `A` record pointing to the VPS IPv4 address. A bare public IPv4 address also works with a short-lived certificate.
- At least 1 GB RAM and 10 GB disk.
- A local Windows or Ubuntu computer where the permanent Ed25519 private key will remain.
- A random panel port between `20000` and `60000`.
- An optional fixed administrative IP/CIDR that may reach the panel.

For a domain deployment, wait until this command returns the VPS address before requesting a certificate:

```bash
getent ahostsv4 <VPN_DOMAIN>
```

## Provider firewall

If the VPS provider has a firewall or security group, allow these inbound connections there as well as on Ubuntu:

| Purpose | Transport | Port |
| --- | --- | --- |
| SSH | TCP | `22` |
| Certificate issuance | TCP | `80` |
| Hysteria2 tunnel | UDP | `443` |
| Subscriptions | TCP | `2096` |
| 3x-ui panel | TCP | your random panel port |

Restrict the panel rule to your administrative IP when practical. Hysteria2 uses UDP; opening only TCP `443` will not work.

TCP `80` must stay reachable for standalone certificate renewal. Nothing listens there between renewal checks.

## Read-only VPS checks

```bash
cat /etc/os-release
uname -m
ip -brief address
curl --fail --show-error https://www.cloudflare.com/cdn-cgi/trace
getent hosts github.com
free -h
df -h /
ss -lntup
systemctl --failed
```

Search for existing VPN software before deployment:

```bash
systemctl list-unit-files | grep -Ei 'x-ui|xray|hysteria|amnezia|wireguard|openvpn' || true
dpkg -l | grep -Ei 'xray|hysteria|amnezia|wireguard|openvpn' || true
```

Do not continue when:

- the host is not Ubuntu 24.04 x86-64;
- the server contains another person's data or an existing VPN deployment;
- the selected UDP tunnel port or TCP panel/subscription ports are occupied;
- DNS or outbound HTTPS does not work;
- the provider blocks inbound UDP on the tunnel port;
- you cannot keep the provider's root session open while testing the new SSH key.

Record real IPs, provider details, ports, and results in a private note. Do not commit that note to this repository.
