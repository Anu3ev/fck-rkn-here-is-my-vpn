# Client applications

Each person receives one private HTTPS subscription URL. This repository recommends OneXray on every supported platform so the import, routing, and troubleshooting steps remain consistent.

Start with the complete [OneXray guide](onexray.md), or send a platform-specific page:

- [iPhone and iPad](user-ios.md)
- [Android](user-android.md)
- [Windows](user-windows.md)
- [macOS](user-macos.md)
- [Linux](user-linux.md)

OneXray officially supports Hysteria2. Install it only from the [official installation page](https://onexray.com/docs/install/), its linked app stores, or its linked GitHub release assets.

## Administrator handoff

1. Copy the intended person's normal `SUB` URL from 3x-ui.
2. Test that URL in OneXray before sending it.
3. Replace the placeholders in the [user message template](user-message-template.md).
4. Send the message through a trusted private channel.

Do not send panel credentials, API tokens, the `health-monitor` link, a public QR code, or another person's link.

## Troubleshooting boundary

If every device fails, run the server diagnostic first. If failure occurs only on one device, update or reset OneXray. If failure occurs only on one Wi-Fi or mobile network, test another network before changing the server because that path may filter UDP.

Record the exact time, device and OneXray version, network type, provider, and a screenshot that hides the subscription URL.
