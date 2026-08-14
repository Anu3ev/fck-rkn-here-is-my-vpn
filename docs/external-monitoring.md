# External monitoring

External monitoring is optional. It detects broad outages but does not prove that a complete Hysteria2 session works from a user's network.

## Suggested free checks

Create checks in UptimeRobot or a similar service:

1. TCP check for `<VPN_DOMAIN>:<VPN_SUBSCRIPTION_PORT>`.
2. TLS certificate-expiry check for the subscription hostname and port.
3. Optional HTTPS check for a deliberately public, non-secret health page when you operate one.

Most simple uptime services do not perform a Hysteria2 handshake or useful UDP probe. Do not create a TCP `443` check and treat it as tunnel monitoring: this deployment listens for the tunnel on UDP. The local `x-ui-health` service remains the end-to-end tunnel check.

Use the longest acceptable free interval. Do not expose the administrative panel merely to monitor it, and never give the monitoring service a subscription URL containing a client ID.

## Telegram notifications

3x-ui can use a Telegram bot for supported alerts and reports. Store the bot token and chat ID only in 3x-ui or a root-only server file.

Recommended alerts include:

- administrative login;
- Xray stop or repeated outbound failure;
- recovery after an outage;
- high CPU or memory use;
- daily status and backup result.

Do not send panel passwords, API tokens, private keys, UUIDs, or full subscription URLs to Telegram.

## Interpretation

- A failed subscription TCP or TLS check can indicate a stopped service, certificate problem, firewall change, provider outage, or blocked route.
- A successful subscription check says nothing about the UDP tunnel.
- The local `x-ui-health` is stronger because it performs HTTPS through the configured Hysteria2 inbound and verifies the egress IP.
