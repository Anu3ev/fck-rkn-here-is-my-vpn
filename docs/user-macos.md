# Connect on macOS

Your administrator will send you one private subscription link. Do not forward it to anyone.

1. Install OneXray from the App Store, or run `brew install --cask onexrayse`. See the [official installation page](https://onexray.com/docs/install/).
2. If you use the download outside the App Store, move `OneXraySE.app` to `Applications` before opening it.
3. Approve OneXray's Network Extension under `System Settings` → `General` → `Login Items & Extensions` when prompted.
4. Copy the complete subscription link.
5. Click `+` and choose subscription, URL, or clipboard import.
6. Select the Hysteria2 node, set Routing to `Global`, and click the power button.
7. Approve the macOS VPN configuration prompt.

The VPN is active when OneXray shows `Connected` and macOS displays the VPN indicator.

To check it, open `https://www.cloudflare.com/cdn-cgi/trace`. The `ip` line should show the VPN server address supplied by your administrator.

If it does not work, follow the common [OneXray troubleshooting guide](onexray.md). Send the administrator the test time, provider, macOS and OneXray versions, and a screenshot with the private link hidden.
