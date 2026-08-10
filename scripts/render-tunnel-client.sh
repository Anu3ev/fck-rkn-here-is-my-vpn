#!/usr/bin/env bash
set -euo pipefail

readonly RUNTIME_CONFIG="${RUNTIME_CONFIG:-/etc/default/vpn}"
readonly CLIENTS_FILE="${CLIENTS_FILE:-/etc/x-ui/health-client.env}"
readonly OUTPUT_FILE="${OUTPUT_FILE:-/etc/x-ui/tunnel-health-client.json}"
readonly XRAY_USER="${XRAY_USER:-x-ui-health}"

# Validates the protected inputs used to render the local health-check client.
validate_inputs() {
  [[ "${EUID}" -eq 0 ]]
  [[ -s "${RUNTIME_CONFIG}" ]]
  [[ -s "${CLIENTS_FILE}" ]]
  id "${XRAY_USER}" >/dev/null
  command -v jq >/dev/null
}

# Writes an Xray client that reaches the public REALITY inbound through SOCKS.
render_config() {
  # shellcheck disable=SC1090 # Both root-owned paths may be overridden for validation.
  source "${RUNTIME_CONFIG}"
  # shellcheck disable=SC1090
  source "${CLIENTS_FILE}"
  [[ -n "${VPN_HEALTH_CLIENT_UUID:-}" ]]
  [[ -n "${VPN_SERVER_ADDRESS:-}" ]]
  [[ "${VPN_XRAY_PORT:-}" =~ ^[0-9]+$ ]]
  [[ -n "${REALITY_PUBLIC_KEY:-}" ]]
  [[ -n "${REALITY_SHORT_ID:-}" ]]
  [[ -n "${REALITY_SERVER_NAME:-}" ]]

  umask 077
  jq -n \
    --arg uuid "${VPN_HEALTH_CLIENT_UUID}" \
    --arg server_address "${VPN_SERVER_ADDRESS}" \
    --argjson server_port "${VPN_XRAY_PORT}" \
    --arg password "${REALITY_PUBLIC_KEY}" \
    --arg short_id "${REALITY_SHORT_ID}" \
    --arg server_name "${REALITY_SERVER_NAME}" \
    '{
      log: {loglevel: "warning"},
      inbounds: [{
        listen: "127.0.0.1",
        port: 10809,
        protocol: "socks",
        settings: {auth: "noauth", udp: false}
      }],
      outbounds: [{
        protocol: "vless",
        settings: {vnext: [{
          address: $server_address,
          port: $server_port,
          users: [{id: $uuid, encryption: "none", flow: "xtls-rprx-vision"}]
        }]},
        streamSettings: {
          network: "tcp",
          security: "reality",
          realitySettings: {
            serverName: $server_name,
            fingerprint: "chrome",
            password: $password,
            shortId: $short_id,
            spiderX: "/"
          }
        }
      }]
    }' > "${OUTPUT_FILE}"

  chown "${XRAY_USER}:${XRAY_USER}" "${OUTPUT_FILE}"
  chmod 600 "${OUTPUT_FILE}"
  [[ -s "${OUTPUT_FILE}" ]]
  [[ "$(stat -c '%a' "${OUTPUT_FILE}")" == "600" ]]
}

validate_inputs
render_config
