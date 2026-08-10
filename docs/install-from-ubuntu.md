# Install from Ubuntu

This guide assumes a new Ubuntu 24.04 x86-64 VPS and an Ubuntu computer with `ssh`, `scp`, and `git`.

Replace every value inside `<ANGLE_BRACKETS>` before running a command.

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
git clone <REPOSITORY_URL> /opt/vpn
```

In a second local terminal, upload only the new public key:

```bash
scp -i <PROVIDER_PRIVATE_KEY_PATH> \
  ~/.ssh/vpn_ed25519.pub \
  root@<SERVER_IP>:/root/vpnadmin.pub
```

## 3. Prepare Ubuntu

Return to the root SSH session and set the deployment values. Use a random high panel port, for example a number between 20000 and 60000.

```bash
cd /opt/vpn
export VPN_SERVER_ADDRESS='<SERVER_IP_OR_DOMAIN>'
export VPN_EXPECTED_EGRESS_IP='<SERVER_PUBLIC_IP>'
export VPN_PANEL_PORT='<RANDOM_HIGH_PORT>'
export VPN_SUBSCRIPTION_PORT='2096'
export VPN_XRAY_PORT='443'
export VPN_CERTIFICATE_FILE=''
export PANEL_ALLOWED_CIDR='<OPTIONAL_ADMIN_PUBLIC_IP/32>'
export ADMIN_PUBLIC_KEY_FILE='/root/vpnadmin.pub'
bash ./deploy.sh prepare
```

Leave `PANEL_ALLOWED_CIDR` empty if your administrative IP changes frequently. The script will securely prompt twice for the new `vpnadmin` sudo password.

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

Continue with [Configure 3x-ui and VLESS REALITY](configure-3x-ui.md). Do not run `enable-operations` until the technical health client file described there exists.
