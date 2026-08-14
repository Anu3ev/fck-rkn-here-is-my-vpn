# OneXray client guide

OneXray is the recommended client for this repository because the same interface and Hysteria2 support are available on iOS, Android, Windows, macOS, and Linux. Use only the [official installation page](https://onexray.com/docs/install/) or its linked stores and GitHub releases.

## Install OneXray

| Platform | Recommended installation |
| --- | --- |
| iPhone or iPad | [App Store](https://apps.apple.com/app/onexray/id6745748773), iOS 15 or newer |
| Android | [Official installation page](https://onexray.com/docs/install/) or the official universal APK linked there, Android 10 or newer |
| Windows | Run `winget install --id YuanDevLLC.OneXray -e` in PowerShell, or use the official installation page |
| macOS | Use the App Store or `brew install --cask onexrayse` |
| Ubuntu desktop | Download the correct DEB from the official installation page, then run `sudo apt install ./OneXray-linux-x86_64.deb` |

Do not download repackaged applications from mirrors, chat attachments, or third-party APK sites.

## Add the private subscription

Your administrator sends one HTTPS subscription URL. Treat it like a password.

1. Copy the complete URL without opening it in a browser.
2. Open OneXray and use `+` on the Home or Subscriptions page.
3. Choose the subscription, URL, clipboard, or pasteboard import option.
4. Paste the URL and save it.
5. Open the imported subscription and refresh it if no node appears.
6. Select the Hysteria2 node created for you.

The exact button text varies by platform. OneXray's [official import guide](https://onexray.com/docs/home/add/) describes every supported import route.

## Connect with the correct routing mode

On the Home screen:

1. confirm that your Hysteria2 node is selected;
2. set Routing to `Global`;
3. press the power or Start button;
4. approve the operating-system VPN or network-extension prompt.

`Global` sends all traffic through the selected node. `Direct` bypasses the VPN, while `Rule` depends on an additional routing profile. Use `Global` for the simple setup in this repository.

Do not edit the imported node, TLS, DNS, TUN, or Hysteria settings unless the administrator asks you to.

## Verify that it works

Open this address after OneXray reports Connected:

```text
https://www.cloudflare.com/cdn-cgi/trace
```

Find the `ip=` line. It must show the VPN server address supplied by the administrator, not the normal home or mobile address. Also open two ordinary sites and play a short video; a green status alone is not a complete test.

## Refresh or reconnect

When the administrator changes the server configuration:

1. stop the VPN;
2. open Subscriptions and refresh your subscription;
3. return Home and select the Hysteria2 node again;
4. confirm `Global` routing and reconnect.

Deleting and importing the same private URL again is safe when refresh does not replace an old node.

## Troubleshooting

If OneXray says Connected but sites do not open:

1. confirm the selected node is Hysteria2 and Routing is `Global`;
2. stop and start OneXray once;
3. close another VPN, proxy, or network-filtering application;
4. refresh the subscription;
5. test Wi-Fi and mobile data or another network;
6. confirm the device date and time are automatic.

If one network works and another does not, that network may be filtering UDP even when the server is healthy.

For administrator support, send:

- the exact local time of the failed attempt;
- device, operating-system version, and OneXray version;
- Wi-Fi/mobile connection and provider name;
- a screenshot of Home with the subscription URL hidden;
- `Core` → `Logs` → `Error Log` text, with links and credentials removed.

The [official log guide](https://onexray.com/docs/setting/log/) also explains the Xray Config and Error Log views. Never post the subscription URL, QR code, authentication value, or an unredacted configuration publicly.
