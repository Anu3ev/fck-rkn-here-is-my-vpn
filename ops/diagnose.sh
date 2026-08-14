#!/usr/bin/env bash
set -euo pipefail

readonly RUNTIME_CONFIG="/etc/default/vpn"
# shellcheck disable=SC1090,SC1091 # Created and protected by deploy.sh.
source "${RUNTIME_CONFIG}"
readonly VPN_EXPECTED_EGRESS_IP VPN_PANEL_PORT VPN_SUBSCRIPTION_PORT VPN_TUNNEL_PORT
readonly VPN_CERTIFICATE_FILE

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

[[ "${EUID}" -eq 0 ]]
[[ -s "${RUNTIME_CONFIG}" ]]
[[ "${VPN_TUNNEL_PORT}" =~ ^[0-9]+$ ]]
[[ "${VPN_SUBSCRIPTION_PORT}" =~ ^[0-9]+$ ]]
[[ "${VPN_PANEL_PORT}" =~ ^[0-9]+$ ]]
[[ "${VPN_EXPECTED_EGRESS_IP}" =~ ^[0-9A-Fa-f:.]+$ ]]

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

if [[ -n "${VPN_CERTIFICATE_FILE}" ]]; then
  check 'panel certificate file' test -f "${VPN_CERTIFICATE_FILE}"
  check 'panel certificate for 24 hours' openssl x509 -checkend 86400 \
    -noout -in "${VPN_CERTIFICATE_FILE}"
else
  printf 'SKIP panel certificate: VPN_CERTIFICATE_FILE is not configured\n'
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
