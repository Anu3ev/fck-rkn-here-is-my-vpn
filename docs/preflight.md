# Preflight checklist

Run this checklist before changing a VPS. Stop if the host is not a new, dedicated server or if an existing VPN must be preserved.

## Required inputs

- A fresh Ubuntu 24.04 LTS x86-64 VPS.
- Temporary root SSH access from the provider.
- A public IPv4 address; a domain is recommended for long-lived HTTPS.
- At least 1 GB RAM and 10 GB disk for a small personal deployment.
- A local Windows or Ubuntu computer where the permanent Ed25519 private key will remain.
- A random high panel port and, optionally, an administrative IP/CIDR allowed to reach it.

## Read-only checks on the VPS

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
systemctl list-unit-files | grep -Ei 'x-ui|xray|amnezia|wireguard|openvpn' || true
dpkg -l | grep -Ei 'xray|amnezia|wireguard|openvpn' || true
```

Do not continue when:

- the host is not Ubuntu 24.04 x86-64;
- the server contains another person's data or an existing VPN deployment;
- TCP ports selected for Xray, subscriptions, or the panel are already occupied;
- DNS or outbound HTTPS does not work;
- the provider blocks the required inbound ports;
- you cannot keep the provider's root session open while testing the new SSH key.

Record the real IPs, provider details, chosen ports, and results in a private deployment note. Do not commit that note to this repository.
