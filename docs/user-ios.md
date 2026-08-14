# Connect on iPhone or iPad

Your administrator will send you one private subscription link. Do not forward it to anyone.

1. Install [OneXray from the App Store](https://apps.apple.com/app/onexray/id6745748773).
2. Copy the complete subscription link.
3. Open OneXray and tap `+`.
4. Choose the subscription or clipboard import option.
5. Save the subscription and select its Hysteria2 node.
6. Set Routing to `Global` and tap the power button.
7. When iOS asks to add a VPN configuration, tap `Allow` and enter your device passcode.

The VPN is active when OneXray shows `Connected` and iOS displays the VPN indicator.

To check it, open `https://www.cloudflare.com/cdn-cgi/trace`. The `ip` line should show the VPN server address supplied by your administrator, not your normal home or mobile address.

If it does not work, follow the common [OneXray troubleshooting guide](onexray.md). Try Wi-Fi and mobile data, then send the administrator the test time, provider, iOS and OneXray versions, and a screenshot with the private link hidden.
