#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly -a SHELL_FILES=(
  deploy.sh
  ops/diagnose.sh
  scripts/backup.sh
  scripts/render-tunnel-client.sh
  scripts/restore.sh
  scripts/show-access.sh
  tests/render-health-client.sh
  tests/repository-validation.sh
)

# Checks every maintained shell entry point before any VPS deployment begins.
validate_shell_syntax() {
  local relative_path
  [[ "${#SHELL_FILES[@]}" -ge 2 ]]
  command -v bash >/dev/null

  for relative_path in "${SHELL_FILES[@]}"; do
    [[ -s "${REPO_ROOT}/${relative_path}" ]]
    bash -n "${REPO_ROOT}/${relative_path}"
  done
}

# Prevents the retired protocol from returning to executable configuration.
validate_tunnel_contract() {
  local matches=""
  local search_status=0
  local -a runtime_paths=(
    "${REPO_ROOT}/.env.example"
    "${REPO_ROOT}/deploy.sh"
    "${REPO_ROOT}/ops"
    "${REPO_ROOT}/scripts"
  )
  [[ -f "${REPO_ROOT}/deploy.sh" ]]
  [[ -f "${REPO_ROOT}/scripts/render-tunnel-client.sh" ]]

  if matches="$(rg -n -i 'vless|reality|VPN_XRAY_PORT|VPN_HEALTH_CLIENT_UUID' \
    "${runtime_paths[@]}")"; then
    printf '%s\n' "${matches}"
    return 1
  else
    search_status=$?
  fi
  [[ "${search_status}" -eq 1 ]]

  # shellcheck disable=SC2016 # The source must contain this literal variable reference.
  grep -Fq 'ufw allow "${VPN_TUNNEL_PORT}/udp"' "${REPO_ROOT}/deploy.sh"
  grep -Fq 'protocol: "hysteria"' "${REPO_ROOT}/scripts/render-tunnel-client.sh"
}

# Runs the repository checks in a deterministic order.
main() {
  [[ -d "${REPO_ROOT}/scripts" ]]
  command -v rg >/dev/null
  validate_shell_syntax
  validate_tunnel_contract
}

main
