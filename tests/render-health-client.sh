#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
test_directory=""

# Removes only the isolated fixture directory created by this test.
cleanup() {
  [[ -z "${test_directory}" ]] && return
  [[ "${test_directory}" == /tmp/vpn-render-test.* ]]
  [[ -d "${test_directory}" ]]
  rm -rf -- "${test_directory}"
}

# Writes representative non-secret runtime and Hysteria2 client inputs.
write_fixtures() {
  local runtime_file="$1"
  local clients_file="$2"
  [[ "${EUID}" -eq 0 ]]
  [[ -d "${test_directory}" ]]

  cat > "${runtime_file}" <<'EOF'
VPN_SERVER_ADDRESS=vpn.example.com
VPN_TUNNEL_PORT=443
VPN_TLS_SERVER_NAME=vpn.example.com
EOF
  cat > "${clients_file}" <<'EOF'
VPN_HEALTH_CLIENT_AUTH=health-client-auth
HYSTERIA_SALAMANDER_PASSWORD=0123456789abcdef0123456789abcdef
EOF
  chmod 600 "${runtime_file}" "${clients_file}"

  [[ -s "${runtime_file}" ]]
  [[ -s "${clients_file}" ]]
}

# Verifies the observable Hysteria2, TLS, masking, and file-mode contract.
assert_rendered_config() {
  local output_file="$1"
  [[ -s "${output_file}" ]]
  [[ "$(stat -c '%a' "${output_file}")" == "600" ]]

  jq -e '
    (.inbounds | length) == 1 and
    .inbounds[0].protocol == "socks" and
    .inbounds[0].settings.udp == true and
    (.outbounds | length) == 1 and
    .outbounds[0].protocol == "hysteria" and
    .outbounds[0].settings.version == 2 and
    .outbounds[0].settings.port == 443 and
    .outbounds[0].streamSettings.network == "hysteria" and
    .outbounds[0].streamSettings.security == "tls" and
    .outbounds[0].streamSettings.tlsSettings.serverName == "vpn.example.com" and
    .outbounds[0].streamSettings.tlsSettings.alpn == ["h3"] and
    .outbounds[0].streamSettings.tlsSettings.allowInsecure == false and
    .outbounds[0].streamSettings.hysteriaSettings.auth == "health-client-auth" and
    .outbounds[0].streamSettings.finalmask.udp[0].type == "salamander"
  ' "${output_file}" >/dev/null
  ! grep -Eiq 'vless|reality|xtls-rprx-vision' "${output_file}"
}

# Runs the renderer through the same root-owned boundary used on the VPS.
main() {
  [[ "${EUID}" -eq 0 ]]
  command -v jq >/dev/null
  test_directory="$(mktemp -d /tmp/vpn-render-test.XXXXXX)"
  local runtime_file="${test_directory}/vpn.env"
  local clients_file="${test_directory}/health-client.env"
  local output_file="${test_directory}/health-client.json"
  write_fixtures "${runtime_file}" "${clients_file}"

  RUNTIME_CONFIG="${runtime_file}" \
    CLIENTS_FILE="${clients_file}" \
    OUTPUT_FILE="${output_file}" \
    XRAY_USER=root \
    bash "${REPO_ROOT}/scripts/render-tunnel-client.sh"

  assert_rendered_config "${output_file}"
}

trap cleanup EXIT
main
