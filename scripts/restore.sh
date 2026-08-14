#!/usr/bin/env bash
set -euo pipefail

mode="restore"
archive="${1:-}"
if [[ "${1:-}" == "--dry-run" ]]; then
  mode="dry-run"
  archive="${2:-}"
fi
readonly MODE="${mode}"
readonly ARCHIVE="${archive}"
restore_dir=""
rescue_archive=""
restored_admin_user=""
restored_panel_port=""
restored_subscription_port=""
restored_tunnel_port=""

# Removes only the temporary extraction directory created by this run.
cleanup() {
  [[ -z "${restore_dir}" ]] && return
  [[ "${restore_dir}" == /var/tmp/x-ui-restore.* ]]
  [[ -d "${restore_dir}" ]]
  rm -rf -- "${restore_dir}"
}

# Rejects an incomplete, corrupt, or unexpected backup before services stop.
validate_archive() {
  local contents
  [[ "${EUID}" -eq 0 ]]
  [[ "${MODE}" == "restore" || "${MODE}" == "dry-run" ]]
  [[ -n "${ARCHIVE}" && -s "${ARCHIVE}" ]]
  contents="$(tar -tzf "${ARCHIVE}")"
  grep -Fxq './etc/x-ui/x-ui.db' <<< "${contents}"
  grep -Fxq './etc/default/vpn' <<< "${contents}"
  grep -Fxq './manifest.txt' <<< "${contents}"
  grep -Fxq './installed-packages.tsv' <<< "${contents}"
}

# Extracts the archive and checks the database while production is untouched.
extract_archive() {
  restore_dir="$(mktemp -d /var/tmp/x-ui-restore.XXXXXX)"
  tar -C "${restore_dir}" -xzf "${ARCHIVE}"

  [[ -s "${restore_dir}/etc/x-ui/x-ui.db" ]]
  [[ "$(sqlite3 "${restore_dir}/etc/x-ui/x-ui.db" 'PRAGMA integrity_check;')" == "ok" ]]
}

# Reads one literal key from an extracted key/value file without executing it.
read_config_value() {
  local path="$1"
  local key="$2"
  local line
  [[ -s "${path}" ]]
  [[ "${key}" =~ ^[A-Z0-9_]+$ ]]
  line="$(grep -m 1 -E "^${key}=" "${path}")"
  [[ -n "${line}" ]]
  printf '%s' "${line#*=}"
}

# Reads and validates values needed to restore user-specific paths and listeners.
load_restored_configuration() {
  local config="${restore_dir}/etc/default/vpn"
  restored_admin_user="$(read_config_value "${config}" VPN_ADMIN_USER)"
  restored_panel_port="$(read_config_value "${config}" VPN_PANEL_PORT)"
  restored_subscription_port="$(read_config_value "${config}" VPN_SUBSCRIPTION_PORT)"
  restored_tunnel_port="$(read_config_value "${config}" VPN_TUNNEL_PORT)"

  [[ "${restored_admin_user}" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]
  id "${restored_admin_user}" >/dev/null
  [[ "${restored_panel_port}" =~ ^[0-9]+$ ]]
  [[ "${restored_subscription_port}" =~ ^[0-9]+$ ]]
  [[ "${restored_tunnel_port}" =~ ^[0-9]+$ ]]
  [[ "${restored_panel_port}" -ge 1 && "${restored_panel_port}" -le 65535 ]]
  [[ "${restored_subscription_port}" -ge 1 && "${restored_subscription_port}" -le 65535 ]]
  [[ "${restored_tunnel_port}" -ge 1 && "${restored_tunnel_port}" -le 65535 ]]
}

# Creates a complete rollback archive before replacing live configuration.
create_rescue_backup() {
  [[ -x /usr/local/sbin/x-ui-backup ]]
  [[ -s /etc/x-ui/x-ui.db ]]
  rescue_archive="$(/usr/local/sbin/x-ui-backup)"

  [[ -s "${rescue_archive}" ]]
  [[ -s "${rescue_archive}.sha256" ]]
}

# Restores one archived path while preserving its recorded ownership and mode.
restore_path() {
  local relative_path="$1"
  local source_path="${restore_dir}/${relative_path}"
  local target_parent
  target_parent="$(dirname "/${relative_path}")"

  [[ -n "${relative_path}" ]]
  [[ "${relative_path}" != /* ]]
  [[ -e "${source_path}" ]] || return 0
  install -d "${target_parent}"
  cp -a "${source_path}" "${target_parent}/"
  [[ -e "/${relative_path}" ]]
}

# Replaces only VPN-owned state and the narrow host configuration it requires.
restore_files() {
  local path
  local -a paths=(
    etc/x-ui
    etc/default/vpn
    etc/default/x-ui
    etc/fail2ban/jail.d/3x-ipl.local
    etc/fail2ban/jail.d/3x-ipl.conf
    etc/ssh/sshd_config.d/00-vpn-hardening.conf
    etc/ufw/user.rules
    etc/ufw/user6.rules
    etc/apt/apt.conf.d/20auto-upgrades
    etc/apt/apt.conf.d/52vpn-unattended-upgrades
    etc/systemd/journald.conf.d/vpn-limits.conf
    etc/logrotate.d/x-ui
    etc/systemd/system/x-ui.service.d/health.conf
    etc/systemd/system/x-ui-health.service
    etc/systemd/system/x-ui-backup.service
    etc/systemd/system/x-ui-backup.timer
    etc/systemd/system/x-ui-cert-renew.service
    etc/systemd/system/x-ui-cert-renew.timer
    root/.x-ui-api-token
    root/.acme.sh
    root/cert
    "home/${restored_admin_user}/.ssh/authorized_keys"
  )

  for path in "${paths[@]}"; do
    restore_path "${path}"
  done

  [[ -s /etc/x-ui/x-ui.db ]]
  [[ -s /etc/default/vpn ]]
}

# Starts restored services and verifies all configured external listeners.
start_and_verify() {
  systemctl daemon-reload
  sshd -t
  ufw reload
  systemctl restart fail2ban systemd-journald
  systemctl enable --now x-ui-health.service x-ui-backup.timer

  if [[ -x /root/.acme.sh/acme.sh ]]; then
    systemctl enable --now x-ui-cert-renew.timer
  fi

  systemctl start x-ui
  for ((attempt = 1; attempt <= 60; attempt++)); do
    if systemctl is-active --quiet x-ui \
      && ss -H -lnu sport = :"${restored_tunnel_port}" | grep -q . \
      && ss -H -lnt sport = :"${restored_subscription_port}" | grep -q . \
      && ss -H -lnt sport = :"${restored_panel_port}" | grep -q .; then
      break
    fi
    sleep 1
  done

  [[ "$(systemctl is-active x-ui)" == "active" ]]
  [[ "$(systemctl is-active x-ui-health)" == "active" ]]
  ss -H -lnu sport = :"${restored_tunnel_port}" | grep -q .
  ss -H -lnt sport = :"${restored_subscription_port}" | grep -q .
  ss -H -lnt sport = :"${restored_panel_port}" | grep -q .
}

trap cleanup EXIT
validate_archive
extract_archive
load_restored_configuration
if [[ "${MODE}" == "dry-run" ]]; then
  printf 'Dry run complete: archive, configuration, and SQLite database are valid.\n'
  exit 0
fi
create_rescue_backup
systemctl stop x-ui x-ui-health.service
restore_files
start_and_verify
printf 'Restore complete. Rollback archive: %s\n' "${rescue_archive}"
