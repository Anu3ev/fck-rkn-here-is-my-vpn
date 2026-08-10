# External monitoring

External monitoring is optional. It detects broad outages but does not prove that a complete VLESS REALITY session works from a user's network.

## Suggested free checks

Create checks in UptimeRobot or a similar service:

1. TCP check for `<SERVER_IP>:<VPN_XRAY_PORT>`.
2. TCP check for `<SERVER_IP>:<VPN_SUBSCRIPTION_PORT>`.
3. HTTPS certificate-expiry check for the subscription hostname and port.

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

- A failed TCP check can indicate a stopped service, firewall change, provider outage, or blocked route.
- A successful TCP check only proves that the port accepted a connection.
- The local `x-ui-health` remains the stronger automated test because it performs HTTPS through the configured REALITY tunnel.
