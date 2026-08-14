# Connect on Linux

Your administrator sends one private subscription URL. Do not forward it.

1. Open the [official OneXray installation page](https://onexray.com/docs/install/) and download the DEB matching your architecture.
2. On an ordinary x86-64 Ubuntu desktop, install it with `sudo apt install ./OneXray-linux-x86_64.deb`.
3. Open OneXray and import the subscription URL with `+`.
4. Select your Hysteria2 node.
5. Set Routing to `Global` and press the power button.
6. Approve any network permission prompt.

Follow the common [OneXray verification and troubleshooting guide](onexray.md). Do not change advanced TUN, DNS, or routing settings for this setup.
