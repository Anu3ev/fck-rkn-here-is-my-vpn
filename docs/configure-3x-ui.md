# Configure 3x-ui and Hysteria2

Complete this common configuration after the `install` phase, regardless of whether you administer the VPS from Windows or Ubuntu.

3x-ui labels can change between releases. Treat the labels below as concepts and compare them with the [official 3x-ui documentation](https://github.com/MHSanaei/3x-ui) when the interface differs.

## 1. Secure the panel and subscription service

Open the management menu on the VPS:

```bash
sudo x-ui
```

Set and save all of the following:

- a unique administrator username and a long random password;
- the panel port stored as `VPN_PANEL_PORT` in `/etc/default/vpn`;
- a random panel web base path;
- the subscription port stored as `VPN_SUBSCRIPTION_PORT`;
- random normal, JSON, and Clash subscription paths;
- HTTPS for both the panel and subscription service.

Do not use `/sub/`, `/json/`, `/clash/`, a root panel path, or default credentials. Store the real values in a password manager, never in Git.

Until HTTPS works, open the panel through an SSH tunnel:

```bash
ssh -L 8443:127.0.0.1:<PANEL_PORT> vpnadmin@<SERVER_IP>
```

Then use the local tunneled address in the browser. Do not send credentials to a public HTTP URL.

## 2. Issue and record the TLS certificate

Confirm that the VPN domain resolves to the VPS, then use the `x-ui` management menu's certificate function to issue a Let's Encrypt certificate. Configure its full-chain and private-key paths for the panel, subscription service, and Hysteria2 inbound.

TCP port `80` remains open for standalone ACME renewal. When `/root/.acme.sh/acme.sh` exists, `enable-operations` enables the renewal timer.

Record the full-chain path for diagnostics:

```bash
sudoedit /etc/default/vpn
```

Set the existing line to the real path:

```text
VPN_CERTIFICATE_FILE=/root/cert/<VPN_DOMAIN>/fullchain.cer
```

The exact path shown by `x-ui` is authoritative. Verify panel and subscription HTTPS from another computer before sharing any link.

## 3. Create one Hysteria2 inbound

First generate the shared Salamander masking password on the VPS and save it in your password manager:

```bash
openssl rand -hex 32
```

In 3x-ui, add one inbound with these properties:

- remark: `hysteria2-primary`;
- protocol: Hysteria2;
- listen address: blank or all interfaces;
- port: `VPN_TUNNEL_PORT`, normally UDP `443`;
- TLS enabled with the certificate and key from the previous step;
- TLS server name: the `VPN_TLS_SERVER_NAME` domain;
- ALPN: `h3`;
- Hysteria version: `2`;
- FinalMask UDP type: `salamander`;
- FinalMask Salamander password: the random value generated above.

Leave QUIC window, congestion, bandwidth, and packet-size tuning at their defaults for the first deployment. A working baseline is easier to diagnose than untested tuning.

Create one enabled client for each person. Give every client:

- a recognizable name;
- its own generated authentication/password value;
- its own random subscription ID;
- optional traffic or expiry limits only when you need them.

Also create a separate client named `health-monitor`. Never send its link to a person. Save the inbound and confirm that 3x-ui shows it as enabled.

## 4. Configure the technical health client

Create a protected file on the VPS:

```bash
sudo install -o root -g root -m 600 /dev/null /etc/x-ui/health-client.env
sudoedit /etc/x-ui/health-client.env
```

Enter the exact authentication value of `health-monitor` and the exact Salamander password from the inbound:

```bash
VPN_HEALTH_CLIENT_AUTH='<HEALTH_MONITOR_AUTH>'
HYSTERIA_SALAMANDER_PASSWORD='<SALAMANDER_PASSWORD>'
```

Keep the quotes and replace only the placeholders. This root-only file contains credentials and must never be copied into the repository.

## 5. Enable and test operations

From the repository on the VPS:

```bash
cd /opt/vpn
sudo bash ./deploy.sh enable-operations
sudo /usr/local/sbin/x-ui-diagnose
```

The deployment renders a local Hysteria2 client, validates its Xray configuration, starts the end-to-end health check, enables backups and certificate renewal, and makes a real HTTPS request through the public tunnel.

Do not continue if the diagnostic reports a failed Hysteria2 request. Check the authentication value, Salamander password, TLS server name, certificate, UDP firewall rule, and inbound port.

## 6. Share one private subscription per person

In the 3x-ui client list, copy the intended person's normal `SUB` URL. Test it yourself, then send it through a trusted private channel with the [OneXray message template](user-message-template.md).

Do not send panel credentials, API tokens, the technical client, or another person's subscription. Complete the [validation checklist](validation.md) before calling the deployment finished.
