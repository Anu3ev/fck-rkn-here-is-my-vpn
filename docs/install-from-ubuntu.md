# Install from Ubuntu

This guide assumes a new Ubuntu 24.04 x86-64 VPS and an Ubuntu computer with `ssh`, `scp`, and `git`. Complete the [preflight checklist](preflight.md) first.

Replace every value inside `<ANGLE_BRACKETS>` before running a command. Local commands run on your computer; VPS commands run inside SSH.

## 1. Generate the administrative SSH key

On your local Ubuntu computer:

```bash
ssh-keygen -t ed25519 -a 64 -f ~/.ssh/vpn_ed25519
```

Protect the private key with a passphrase. Never upload or copy the private key to the VPS.

## 2. Connect to the new VPS

Use the temporary root access supplied by the VPS provider:

```bash
ssh -i <PROVIDER_PRIVATE_KEY_PATH> root@<SERVER_IP>
```

In that root session, install Git and clone this repository:

```bash
apt-get update
apt-get install -y git
git clone https://github.com/Anu3ev/fck-rkn-here-is-my-vpn.git /opt/vpn
```

In a second local terminal, upload only the new public key:

```bash
scp -i <PROVIDER_PRIVATE_KEY_PATH> \
  ~/.ssh/vpn_ed25519.pub \
  root@<SERVER_IP>:/root/vpnadmin.pub
```

## 3. Prepare Ubuntu

Return to the root SSH session and set the deployment values. Prefer the VPN domain as `VPN_SERVER_ADDRESS`; it keeps user links valid if the VPS IP later changes.

```bash
cd /opt/vpn
export VPN_SERVER_ADDRESS='<VPN_DOMAIN_OR_SERVER_IP>'
export VPN_EXPECTED_EGRESS_IP='<SERVER_PUBLIC_IP>'
export VPN_PANEL_PORT='<RANDOM_HIGH_PORT>'
export VPN_SUBSCRIPTION_PORT='2096'
export VPN_TUNNEL_PORT='443'
export VPN_TLS_SERVER_NAME='<VPN_DOMAIN_OR_SERVER_IP>'
export VPN_CERTIFICATE_MODE='<domain_OR_ip>'
export VPN_CERTIFICATE_FILE=''
export VPN_CERTIFICATE_KEY_FILE=''
export VPN_ACME_HTTP_PORT='80'
export PANEL_ALLOWED_CIDR='<OPTIONAL_ADMIN_PUBLIC_IP/32>'
export ADMIN_PUBLIC_KEY_FILE='/root/vpnadmin.pub'
bash ./deploy.sh prepare
```

Leave `PANEL_ALLOWED_CIDR` empty if your administrative IP changes frequently. The script prompts twice for a new `vpnadmin` sudo password. Save it in a password manager.

Use `VPN_CERTIFICATE_MODE='domain'` when `VPN_TLS_SERVER_NAME` is a hostname. Use `VPN_CERTIFICATE_MODE='ip'` when it is the bare public IPv4 address.

## 4. Verify the new SSH account

Do not close the existing root session. Open another local terminal:

```bash
ssh -i ~/.ssh/vpn_ed25519 vpnadmin@<SERVER_IP>
```

Run `sudo true` and enter the new sudo password. Keep this new session open.

Only after both SSH and sudo work, return to the original root session:

```bash
cd /opt/vpn
KEY_LOGIN_VERIFIED=verified bash ./deploy.sh harden-ssh
```

Open one more independent `vpnadmin` session to confirm the hardened configuration still accepts the key.

## 5. Install 3x-ui

From the root session:

```bash
cd /opt/vpn
bash ./deploy.sh install
```

Continue with [Configure 3x-ui and Hysteria2](configure-3x-ui.md). Do not run `enable-operations` until the technical health-client file described there exists.
