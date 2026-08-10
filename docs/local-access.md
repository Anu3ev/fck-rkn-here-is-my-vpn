# Optional local access storage

A password manager is the preferred place for the panel credentials and user subscriptions. The scripts in this repository are optional convenience tools for people who deliberately keep local access records outside Git.

## Windows with DPAPI

`scripts/show-access.ps1` expects DPAPI-encrypted files owned by the current Windows user. Its default deployment name is `vpn`, and its default directory is:

```text
%USERPROFILE%\.config\vpn
```

Required files:

```text
x-ui-3x-ui.dpapi
x-ui-subscriptions.dpapi
```

The first encrypted value must decrypt to this key/value format:

```text
XUI_ACCESS_URL=<PANEL_HTTPS_URL>
XUI_USERNAME=<PANEL_USER>
XUI_PASSWORD=<PANEL_PASSWORD>
```

The second must decrypt to a JSON object mapping a person's name to their subscription URL. Create the DPAPI files locally with `ConvertTo-SecureString` and `ConvertFrom-SecureString`; never create plaintext copies inside the repository.

Display them only when needed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\show-access.ps1
```

## Ubuntu with mode-600 files

Create the private directory:

```bash
install -d -m 700 ~/.config/vpn
umask 077
```

Create `x-ui-3x-ui.env` using the same three key/value lines shown above. Create `x-ui-subscriptions.json` as a JSON object whose values are subscription URLs. Both files must have mode `600` or `400`.

Display them only when needed:

```bash
bash ./scripts/show-access.sh
```

Linux mode bits restrict other local users but do not encrypt the files. Use full-disk encryption or a password manager when the computer may be lost or shared.
