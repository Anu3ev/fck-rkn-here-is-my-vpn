# Connect on Windows

Your administrator will send you one private subscription link. Do not forward it to anyone.

1. Open PowerShell and run `winget install --id YuanDevLLC.OneXray -e`, or use the [official OneXray installation page](https://onexray.com/docs/install/).
2. Install and open OneXray.
3. Copy the complete subscription link.
4. Click `+` and choose subscription, URL, or clipboard import.
5. Paste the link manually if it was not detected.
6. Select the imported Hysteria2 node, set Routing to `Global`, and click the power button.
7. Approve the Windows network or VPN component prompt if it appears.

The VPN is active when OneXray shows `Connected`.

To check it, open `https://www.cloudflare.com/cdn-cgi/trace`. The `ip` line should show the VPN server address supplied by your administrator.

If it does not work, follow the common [OneXray troubleshooting guide](onexray.md). Send the administrator the test time, provider, Windows and OneXray versions, and a screenshot with the private link hidden.
