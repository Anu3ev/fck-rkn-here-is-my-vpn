# Configure 3x-ui and VLESS REALITY

Complete this common configuration after the `install` phase, regardless of whether you administer the VPS from Windows or Ubuntu.

3x-ui changes its interface over time. Use the labels in this guide as concepts, and check the [official 3x-ui documentation](https://github.com/MHSanaei/3x-ui) if a menu label differs.

## 1. Secure the panel

Run the management menu on the VPS:

```bash
sudo x-ui
```

Confirm or change all of the following:

- a unique administrator username;
- a long random administrator password;
- the panel port configured in `/etc/default/vpn`;
- a random panel web base path;
- HTTPS with a valid certificate;
- a random subscription path;
- a random JSON subscription path;
- a random Clash subscription path.

Do not use `/sub/`, `/json/`, `/clash/`, a root panel path, or default credentials. Store the generated values in a password manager, not in Git.

If HTTPS is not ready, access the panel temporarily through an SSH tunnel instead of sending credentials over public HTTP:

```bash
ssh -L 8443:127.0.0.1:<PANEL_PORT> vpnadmin@<SERVER_IP>
```

Then open the local tunneled address in your browser. Do not expose an HTTP-only panel permanently.

## 2. Configure the certificate

A domain pointing to the VPS is the simplest long-term option. Use the `x-ui` management menu to issue and install a Let's Encrypt certificate, then configure the same certificate files for the panel and subscription service.

The repository keeps TCP port 80 open for standalone ACME renewal. When `/root/.acme.sh/acme.sh` exists, `enable-operations` enables the certificate renewal timer automatically.

After the certificate is installed, set `VPN_CERTIFICATE_FILE` in `/etc/default/vpn` to its fullchain PEM path so the diagnostic command can check expiry.

Verify HTTPS from another computer before sharing any subscription link.

## 3. Create the REALITY inbound

Create one inbound with these intended properties:

- protocol: VLESS;
- listen port: the configured `VPN_XRAY_PORT`, normally `443`;
- transport/network: TCP or Raw, depending on the current UI wording;
- security: REALITY;
- flow: `xtls-rprx-vision`;
- a credible REALITY destination and matching server name;
- a generated REALITY private/public key pair;
- at least one generated short ID;
- fingerprint: `chrome` for clients.

Create a separate client for every person. Each client must have its own UUID and subscription ID. Also create one disabled-from-sharing technical client named `health-monitor`; its UUID is used only by the server-side tunnel check.

Do not enable unrelated protocols or create one shared UUID for a family or team.

## 4. Create the root-only health file

On the VPS, create the protected file:

```bash
sudo install -o root -g root -m 600 /dev/null /etc/x-ui/health-client.env
sudoedit /etc/x-ui/health-client.env
```

Enter the real values from the inbound and technical client:

```bash
VPN_HEALTH_CLIENT_UUID='<HEALTH_CLIENT_UUID>'
REALITY_PUBLIC_KEY='<REALITY_PUBLIC_KEY>'
REALITY_SHORT_ID='<REALITY_SHORT_ID>'
REALITY_SERVER_NAME='<REALITY_SERVER_NAME>'
```

This file contains credentials. Never copy it into the repository.

## 5. Enable operations

From the repository on the VPS:

```bash
cd /opt/vpn
sudo bash ./deploy.sh enable-operations
sudo /usr/local/sbin/x-ui-diagnose
```

The command renders a local Xray client, validates its configuration, enables the daily backup timer, enables certificate renewal when available, and makes a real HTTPS request through the public REALITY inbound.

## 6. Share access

Copy only the intended person's subscription URL from 3x-ui. Send it through a trusted private channel. Do not send panel credentials, API tokens, UUIDs, or another person's subscription.

Continue with the [validation checklist](validation.md) before calling the deployment complete.
