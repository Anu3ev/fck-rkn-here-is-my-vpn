# Migrate an existing VLESS deployment to Hysteria2

Use this guide only for an existing server. New deployments should create Hysteria2 directly. The safe migration keeps the old inbound temporarily, validates one representative client, and removes the old protocol only after Hysteria2 works.

## 1. Back up and record the current state

```bash
sudo /usr/local/sbin/x-ui-backup
sudo /usr/local/sbin/x-ui-diagnose
sudo ss -lntup
```

Copy the backup and checksum off the VPS. Record the current user names and subscription IDs in a private note, without putting credentials in Git.

## 2. Prepare the Hysteria2 runtime values

Update `/etc/default/vpn`:

```text
VPN_TUNNEL_PORT=443
VPN_TLS_SERVER_NAME=<VPN_DOMAIN>
```

Remove the obsolete `VPN_XRAY_PORT` line after confirming the new values are saved. Allow UDP, then verify the rule:

```bash
sudo ufw allow 443/udp
sudo ufw status
```

Also allow UDP `443` in the VPS provider firewall or security group.

## 3. Create and validate Hysteria2 in parallel

Follow [Configure 3x-ui and Hysteria2](configure-3x-ui.md). Keep the old inbound enabled while creating `hysteria2-primary`.

For the first representative client:

1. create a new Hysteria2 client with its own authentication value;
2. preserve that person's existing subscription ID when practical;
3. refresh the subscription in OneXray;
4. select Hysteria2, choose Global routing, and connect;
5. verify the egress IP and ordinary websites from the network that previously had problems.

Do not migrate every client until this one complete path works.

## 4. Move all users and the health check

Create a separate Hysteria2 client for each remaining person. Preserve subscription IDs to avoid sending new URLs when possible, then ask each person to refresh and select Hysteria2.

Create the separate `health-monitor` client and replace `/etc/x-ui/health-client.env` with:

```bash
VPN_HEALTH_CLIENT_AUTH='<HEALTH_MONITOR_AUTH>'
HYSTERIA_SALAMANDER_PASSWORD='<SALAMANDER_PASSWORD>'
```

Install the updated operational files and test the new tunnel:

```bash
cd /opt/vpn
sudo bash ./deploy.sh install
sudo bash ./deploy.sh enable-operations
sudo /usr/local/sbin/x-ui-diagnose
```

## 5. Remove the old inbound

Only after all active people have connected through Hysteria2:

1. disable the old inbound;
2. wait through a normal usage window;
3. confirm Hysteria2 traffic counters and the health check continue to work;
4. delete the old inbound;
5. remove its obsolete TCP firewall rule if no other service uses it.

For a tunnel on port `443`, keep `443/udp` and remove only `443/tcp`:

```bash
sudo ufw delete allow 443/tcp
sudo ufw status
sudo /usr/local/sbin/x-ui-diagnose
```

The normal subscription, panel, and certificate services still use their documented TCP ports. Never delete a firewall rule until its exact purpose is known.
