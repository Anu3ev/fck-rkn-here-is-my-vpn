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

# Writes an Xray client that reaches the public Hysteria2 inbound through SOCKS.
render_config() {
  # shellcheck disable=SC1090 # Both root-owned paths may be overridden for validation.
  source "${RUNTIME_CONFIG}"
  # shellcheck disable=SC1090
  source "${CLIENTS_FILE}"
  [[ -n "${VPN_HEALTH_CLIENT_AUTH:-}" ]]
  [[ -n "${VPN_SERVER_ADDRESS:-}" ]]
  [[ "${VPN_TUNNEL_PORT:-}" =~ ^[0-9]+$ ]]
  [[ "${VPN_TUNNEL_PORT}" -ge 1 && "${VPN_TUNNEL_PORT}" -le 65535 ]]
  [[ -n "${VPN_TLS_SERVER_NAME:-}" ]]
  [[ -n "${HYSTERIA_SALAMANDER_PASSWORD:-}" ]]
  [[ "${#HYSTERIA_SALAMANDER_PASSWORD}" -ge 16 ]]

  umask 077
  jq -n \
    --arg auth "${VPN_HEALTH_CLIENT_AUTH}" \
    --arg server_address "${VPN_SERVER_ADDRESS}" \
    --argjson server_port "${VPN_TUNNEL_PORT}" \
    --arg server_name "${VPN_TLS_SERVER_NAME}" \
    --arg salamander_password "${HYSTERIA_SALAMANDER_PASSWORD}" \
    '{
      log: {loglevel: "warning"},
      inbounds: [{
        listen: "127.0.0.1",
        port: 10809,
        protocol: "socks",
        settings: {auth: "noauth", udp: true}
      }],
      outbounds: [{
        protocol: "hysteria",
        settings: {
          version: 2,
          address: $server_address,
          port: $server_port
        },
        streamSettings: {
          network: "hysteria",
          security: "tls",
          tlsSettings: {
            serverName: $server_name,
            alpn: ["h3"],
            allowInsecure: false
          },
          hysteriaSettings: {
            version: 2,
            auth: $auth
          },
          finalmask: {
            udp: [{
              type: "salamander",
              settings: {password: $salamander_password}
            }]
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
