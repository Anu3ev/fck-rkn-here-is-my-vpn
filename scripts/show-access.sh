#!/usr/bin/env bash
set -euo pipefail

readonly SECRET_DIRECTORY="${1:-${XDG_CONFIG_HOME:-${HOME}/.config}/vpn}"
readonly DEPLOYMENT_NAME="${2:-vpn}"
readonly PANEL_FILE="${SECRET_DIRECTORY}/${DEPLOYMENT_NAME}-3x-ui.env"
readonly SUBSCRIPTIONS_FILE="${SECRET_DIRECTORY}/${DEPLOYMENT_NAME}-subscriptions.json"

# Rejects missing or broadly readable local secret files before printing them.
validate_secret_file() {
  local path="$1"
  local mode
  [[ -n "${path}" ]]
  [[ -s "${path}" ]]
  mode="$(stat -c '%a' "${path}")"
  [[ "${mode}" == "600" || "${mode}" == "400" ]]
}

# Reads one literal key from the local panel file without executing its content.
read_panel_setting() {
  local key="$1"
  local line
  [[ -s "${PANEL_FILE}" ]]
  [[ "${key}" =~ ^[A-Z0-9_]+$ ]]
  line="$(grep -m 1 -E "^${key}=" "${PANEL_FILE}")"
  [[ -n "${line}" ]]
  printf '%s' "${line#*=}"
}

# Prints the panel fields and subscription map after validating their formats.
show_access() {
  local panel_url
  local panel_user
  local panel_password
  panel_url="$(read_panel_setting XUI_ACCESS_URL)"
  panel_user="$(read_panel_setting XUI_USERNAME)"
  panel_password="$(read_panel_setting XUI_PASSWORD)"
  [[ -n "${panel_url}" ]]
  [[ -n "${panel_user}" ]]
  [[ -n "${panel_password}" ]]
  jq -e 'type == "object" and length > 0' "${SUBSCRIPTIONS_FILE}" >/dev/null

  printf 'Panel URL\t%s\n' "${panel_url}"
  printf 'Panel user\t%s\n' "${panel_user}"
  printf 'Panel password\t%s\n' "${panel_password}"
  jq -r 'to_entries[] | "Subscription \(.key)\t\(.value)"' "${SUBSCRIPTIONS_FILE}"
}

validate_secret_file "${PANEL_FILE}"
validate_secret_file "${SUBSCRIPTIONS_FILE}"
command -v jq >/dev/null
show_access
