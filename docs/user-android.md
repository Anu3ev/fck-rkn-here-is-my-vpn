# Connect on Android

Your administrator will send you one private subscription link. Do not forward it to anyone.

1. Install OneXray using its [official installation page](https://onexray.com/docs/install/).
2. If it is unavailable in your app store, use only the universal APK linked by the official page. Do not use an APK mirror.
3. Copy the complete subscription link.
4. Open OneXray and tap `+`.
5. Choose subscription, URL, or clipboard import.
6. Select the Hysteria2 node, set Routing to `Global`, and tap the power button.
7. Allow Android to create the VPN connection.

The VPN is active when OneXray shows `Connected` and Android displays a VPN or key indicator.

To check it, open `https://www.cloudflare.com/cdn-cgi/trace`. The `ip` line should show the VPN server address supplied by your administrator.

If it does not work, follow the common [OneXray troubleshooting guide](onexray.md). Try Wi-Fi and mobile data, then send the administrator the test time, provider, Android and OneXray versions, and a screenshot with the private link hidden.
