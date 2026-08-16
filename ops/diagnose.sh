#!/usr/bin/env bash
set -euo pipefail

readonly RUNTIME_CONFIG="/etc/default/vpn"
# shellcheck disable=SC1090,SC1091 # Created and protected by deploy.sh.
source "${RUNTIME_CONFIG}"
readonly VPN_SERVER_ADDRESS VPN_EXPECTED_EGRESS_IP VPN_PANEL_PORT
readonly VPN_SUBSCRIPTION_PORT VPN_TUNNEL_PORT VPN_TLS_SERVER_NAME
readonly VPN_CERTIFICATE_MODE VPN_CERTIFICATE_FILE VPN_CERTIFICATE_KEY_FILE

# Prints a check name and fails the diagnostic run when its command fails.
check() {
  local name="$1"
  shift
  [[ -n "${name}" ]]
  [[ "$#" -gt 0 ]]

  if "$@" >/dev/null 2>&1; then
    printf 'OK   %s\n' "${name}"
    return
  fi

  printf 'FAIL %s\n' "${name}"
  return 1
}

# Confirms that an HTTPS request exits through the configured Hysteria2 tunnel.
check_tunnel() {
  local trace
  local exit_ip
  trace="$(curl --silent --show-error --fail --max-time 20 \
    --socks5-hostname 127.0.0.1:10809 \
    'https://www.cloudflare.com/cdn-cgi/trace')"
  exit_ip="$(awk -F= '$1 == "ip" {print $2}' <<< "${trace}")"

  [[ -n "${exit_ip}" ]]
  [[ "${exit_ip}" == "${VPN_EXPECTED_EGRESS_IP}" ]]
}

# Confirms that a configured TCP or UDP listener exists on the host.
check_listener() {
  local transport="$1"
  local port="$2"
  [[ "${transport}" == "tcp" || "${transport}" == "udp" ]]
  [[ "${port}" =~ ^[0-9]+$ ]]

  if [[ "${transport}" == "udp" ]]; then
    ss -H -lnu "sport = :${port}" | grep -q .
    return
  fi

  ss -H -lnt "sport = :${port}" | grep -q .
}

# Confirms that acme.sh retains the renewal configuration for this identity.
check_certificate_registration() {
  local acme_bin='/root/.acme.sh/acme.sh'
  [[ -x "${acme_bin}" ]]
  [[ -n "${VPN_TLS_SERVER_NAME}" ]]

  "${acme_bin}" --list \
    | awk -v name="${VPN_TLS_SERVER_NAME}" '$1 == name {print $1}' \
    | grep -Fxq "${VPN_TLS_SERVER_NAME}"
}

# Confirms that the installed certificate and private key are one pair.
check_certificate_key_pair() {
  local certificate_digest=""
  local private_key_digest=""
  [[ -f "${VPN_CERTIFICATE_FILE}" ]] || return 1
  [[ -f "${VPN_CERTIFICATE_KEY_FILE}" ]] || return 1

  certificate_digest="$(openssl x509 -in "${VPN_CERTIFICATE_FILE}" \
    -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum | awk '{print $1}')"
  private_key_digest="$(openssl pkey -in "${VPN_CERTIFICATE_KEY_FILE}" \
    -pubout -outform DER | sha256sum | awk '{print $1}')"

  [[ -n "${certificate_digest}" ]]
  [[ "${certificate_digest}" == "${private_key_digest}" ]]
}

# Confirms that the certificate covers the configured domain or public IP.
check_certificate_identity() {
  [[ -f "${VPN_CERTIFICATE_FILE}" ]] || return 1
  [[ "${VPN_CERTIFICATE_MODE}" == "domain" \
    || "${VPN_CERTIFICATE_MODE}" == "ip" ]] || return 1

  if [[ "${VPN_CERTIFICATE_MODE}" == "ip" ]]; then
    openssl x509 -in "${VPN_CERTIFICATE_FILE}" -noout \
      -checkip "${VPN_TLS_SERVER_NAME}" >/dev/null
    return
  fi

  openssl x509 -in "${VPN_CERTIFICATE_FILE}" -noout \
    -checkhost "${VPN_TLS_SERVER_NAME}" >/dev/null
}

# Confirms that 3x-ui serves the same certificate that renewal maintains on disk.
check_served_certificate() {
  local installed_fingerprint=""
  local served_fingerprint=""
  [[ "${VPN_PANEL_PORT}" =~ ^[0-9]+$ ]]
  [[ -f "${VPN_CERTIFICATE_FILE}" ]] || return 1

  installed_fingerprint="$(openssl x509 -in "${VPN_CERTIFICATE_FILE}" \
    -noout -fingerprint -sha256)"
  served_fingerprint="$(timeout 15 openssl s_client \
    -connect "127.0.0.1:${VPN_PANEL_PORT}" \
    -servername "${VPN_TLS_SERVER_NAME}" -showcerts </dev/null 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256)"

  [[ -n "${served_fingerprint}" ]]
  [[ "${served_fingerprint}" == "${installed_fingerprint}" ]]
}

# Performs a trusted TLS handshake against the public panel address.
check_public_panel_tls() {
  local panel_url="https://${VPN_TLS_SERVER_NAME}:${VPN_PANEL_PORT}/"
  local -a curl_arguments=(--silent --show-error --max-time 20 --output /dev/null)
  [[ -n "${VPN_SERVER_ADDRESS}" ]]
  [[ -n "${VPN_TLS_SERVER_NAME}" ]]

  if [[ "${VPN_SERVER_ADDRESS}" != "${VPN_TLS_SERVER_NAME}" ]]; then
    curl_arguments+=(--resolve \
      "${VPN_TLS_SERVER_NAME}:${VPN_PANEL_PORT}:${VPN_SERVER_ADDRESS}")
  fi

  curl "${curl_arguments[@]}" "${panel_url}"
}

[[ "${EUID}" -eq 0 ]]
[[ -s "${RUNTIME_CONFIG}" ]]
[[ "${VPN_TUNNEL_PORT}" =~ ^[0-9]+$ ]]
[[ "${VPN_SUBSCRIPTION_PORT}" =~ ^[0-9]+$ ]]
[[ "${VPN_PANEL_PORT}" =~ ^[0-9]+$ ]]
[[ "${VPN_EXPECTED_EGRESS_IP}" =~ ^[0-9A-Fa-f:.]+$ ]]
[[ "${VPN_TLS_SERVER_NAME}" =~ ^[A-Za-z0-9.-]+$ ]]
[[ "${VPN_CERTIFICATE_MODE}" == "domain" || "${VPN_CERTIFICATE_MODE}" == "ip" ]]

printf '== System ==\n'
printf 'Uptime: %s\n' "$(uptime -p)"
printf 'CPU used: %s\n' \
  "$(LC_ALL=C top -bn1 | awk '/^%Cpu/ {printf "%.1f%%", 100 - $8; exit}')"
printf 'RAM used: %s\n' "$(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
df -h / | awk 'NR == 2 {printf "Disk /: %s/%s, free %s\n", $3, $2, $4}'

printf '\n== Services and network ==\n'
check '3x-ui service' systemctl is-active --quiet x-ui
check 'Xray process' pgrep -f '^/usr/local/x-ui/bin/xray-linux-amd64'
check 'health client service' systemctl is-active --quiet x-ui-health
check 'automatic security updates' systemctl is-active --quiet unattended-upgrades
check 'Fail2Ban' systemctl is-active --quiet fail2ban
check 'direct HTTPS' curl --silent --show-error --fail --max-time 20 \
  --output /dev/null https://www.cloudflare.com/
check 'Hysteria2 HTTPS request' check_tunnel
check "Hysteria2 UDP port ${VPN_TUNNEL_PORT}" \
  check_listener udp "${VPN_TUNNEL_PORT}"
check "subscription TCP port ${VPN_SUBSCRIPTION_PORT}" \
  check_listener tcp "${VPN_SUBSCRIPTION_PORT}"
check "panel TCP port ${VPN_PANEL_PORT}" check_listener tcp "${VPN_PANEL_PORT}"
check 'backup timer' systemctl is-active --quiet x-ui-backup.timer

if [[ -n "${VPN_CERTIFICATE_FILE}" && -n "${VPN_CERTIFICATE_KEY_FILE}" ]]; then
  check 'panel certificate file' test -f "${VPN_CERTIFICATE_FILE}"
  check 'panel certificate key file' test -f "${VPN_CERTIFICATE_KEY_FILE}"
  check 'panel certificate for 48 hours' openssl x509 -checkend 172800 \
    -noout -in "${VPN_CERTIFICATE_FILE}"
  check 'panel certificate identity' check_certificate_identity
  check 'panel certificate and private key match' check_certificate_key_pair
  check 'certificate registered for renewal' check_certificate_registration
  check 'panel serves the installed certificate' check_served_certificate
  check 'public panel TLS trust' check_public_panel_tls
  check 'certificate renewal timer' systemctl is-active --quiet x-ui-cert-renew.timer
else
  printf 'SKIP panel certificate: certificate paths are not configured\n'
fi

printf '\nOpen TCP/UDP ports:\n'
ss -H -lntup | awk '{print $1, $5, $7}' | sort -u
printf '\nFirewall:\n'
ufw status

printf '\n== Versions ==\n'
printf '3x-ui: %s\n' "$(/usr/local/x-ui/x-ui -v | tail -n 1)"
printf 'Xray: %s\n' \
  "$(/usr/local/x-ui/bin/xray-linux-amd64 version | head -n 1)"

printf '\n== Recent warnings and restarts ==\n'
recent_events="$(journalctl -u x-ui -u x-ui-health \
  --since '-24 hours' -p warning -n 20 --no-pager -o short-iso 2>/dev/null || true)"
if [[ -z "${recent_events}" || "${recent_events}" == '-- No entries --' ]]; then
  printf 'No warnings in the last 24 hours.\n'
else
  sed -E \
    -e 's#https?://[^[:space:]]+#<URL_REDACTED>#g' \
    -e 's#/(sub|json|clash)/[A-Za-z0-9_-]+#/<PATH_REDACTED>#g' \
    -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}/<UUID_REDACTED>/g' \
    <<< "${recent_events}"
fi
systemctl show x-ui --property=NRestarts --property=ActiveEnterTimestamp
