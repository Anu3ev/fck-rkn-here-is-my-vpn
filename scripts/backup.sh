#!/usr/bin/env bash
set -euo pipefail

readonly RUNTIME_CONFIG="/etc/default/vpn"
# shellcheck disable=SC1090,SC1091 # Created and protected by deploy.sh.
source "${RUNTIME_CONFIG}"
readonly VPN_ADMIN_USER
readonly BACKUP_DIR="/var/backups/x-ui"
readonly RETENTION_DAYS="${RETENTION_DAYS:-14}"
staging_dir=""

# Removes only the temporary directory created for this backup run.
cleanup() {
  [[ -z "${staging_dir}" ]] && return
  [[ "${staging_dir}" == "${BACKUP_DIR}"/.staging.* ]]
  [[ -d "${staging_dir}" ]]
  rm -rf -- "${staging_dir}"
}

# Verifies the commands and protected state required for a consistent backup.
validate_environment() {
  [[ "${EUID}" -eq 0 ]]
  [[ -s "${RUNTIME_CONFIG}" ]]
  [[ -s /etc/x-ui/x-ui.db ]]
  [[ "${VPN_ADMIN_USER}" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]
  command -v sqlite3 >/dev/null
  command -v sha256sum >/dev/null
}

# Creates a root-only staging area under the final backup directory.
prepare_staging() {
  install -d -o root -g root -m 700 "${BACKUP_DIR}"
  staging_dir="$(mktemp -d "${BACKUP_DIR}/.staging.XXXXXX")"
  [[ -d "${staging_dir}" ]]
  [[ "${staging_dir}" == "${BACKUP_DIR}"/.staging.* ]]
}

# Uses SQLite's online backup command and verifies the copied database.
backup_database() {
  install -d -m 700 "${staging_dir}/etc/x-ui"
  sqlite3 /etc/x-ui/x-ui.db ".timeout 10000" \
    ".backup '${staging_dir}/etc/x-ui/x-ui.db'"
  [[ -s "${staging_dir}/etc/x-ui/x-ui.db" ]]
  [[ "$(sqlite3 "${staging_dir}/etc/x-ui/x-ui.db" 'PRAGMA integrity_check;')" == "ok" ]]
}

# Copies only the files required to restore this deployment.
copy_configuration() {
  local source
  local copied=0
  local -a sources=(
    /etc/default/vpn
    /etc/default/x-ui
    /etc/x-ui/install-result.env
    /etc/x-ui/health-client.env
    /etc/x-ui/tunnel-health-client.json
    /etc/fail2ban/jail.d/3x-ipl.local
    /etc/fail2ban/jail.d/3x-ipl.conf
    /etc/ssh/sshd_config.d/00-vpn-hardening.conf
    /etc/ufw/user.rules
    /etc/ufw/user6.rules
    /etc/apt/apt.conf.d/20auto-upgrades
    /etc/apt/apt.conf.d/52vpn-unattended-upgrades
    /etc/systemd/journald.conf.d/vpn-limits.conf
    /etc/logrotate.d/x-ui
    /etc/systemd/system/x-ui.service.d/health.conf
    /etc/systemd/system/x-ui-health.service
    /etc/systemd/system/x-ui-backup.service
    /etc/systemd/system/x-ui-backup.timer
    /etc/systemd/system/x-ui-cert-renew.service
    /etc/systemd/system/x-ui-cert-renew.timer
    /root/.x-ui-api-token
    /root/.acme.sh
    /root/cert
    "/home/${VPN_ADMIN_USER}/.ssh/authorized_keys"
  )

  for source in "${sources[@]}"; do
    [[ -e "${source}" ]] || continue
    cp -a --parents "${source}" "${staging_dir}"
    copied=$((copied + 1))
  done

  [[ "${copied}" -ge 8 ]]
  [[ -s "${staging_dir}/etc/default/vpn" ]]
}

# Records installed Debian packages needed to reproduce the host.
write_package_list() {
  local package_list="${staging_dir}/installed-packages.tsv"
  dpkg-query --show --showformat='${binary:Package}\t${Version}\n' > "${package_list}"

  [[ -s "${package_list}" ]]
  grep -q '^curl[[:space:]]' "${package_list}"
}

# Records versions and service state without embedding credentials.
write_manifest() {
  local manifest="${staging_dir}/manifest.txt"
  {
    printf 'created_utc=%s\n' "$(date --utc --iso-8601=seconds)"
    printf 'hostname=%s\n' "$(hostname)"
    # shellcheck disable=SC1091 # Guaranteed by the supported Ubuntu host.
    printf 'os=%s\n' "$(. /etc/os-release && printf '%s' "${PRETTY_NAME}")"
    printf 'panel_version=%s\n' "$(/usr/local/x-ui/x-ui -v | tail -n 1)"
    printf 'xray_version=%s\n' \
      "$(/usr/local/x-ui/bin/xray-linux-amd64 version | head -n 1)"
    printf 'x_ui_active=%s\n' "$(systemctl is-active x-ui)"
  } > "${manifest}"

  [[ -s "${manifest}" ]]
  grep -q '^created_utc=' "${manifest}"
}

# Builds a root-only archive and a SHA-256 checksum beside it.
create_archive() {
  local timestamp
  local archive
  timestamp="$(date --utc +%Y%m%dT%H%M%SZ)"
  archive="${BACKUP_DIR}/x-ui-${timestamp}.tar.gz"

  tar -C "${staging_dir}" -czf "${archive}" .
  chmod 600 "${archive}"
  (cd "${BACKUP_DIR}" && sha256sum "$(basename "${archive}")" \
    > "$(basename "${archive}").sha256")
  chmod 600 "${archive}.sha256"

  [[ -s "${archive}" ]]
  [[ -s "${archive}.sha256" ]]
  printf '%s\n' "${archive}"
}

# Deletes only expired archives created in the fixed backup directory.
prune_expired() {
  [[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]]
  [[ "${BACKUP_DIR}" == "/var/backups/x-ui" ]]
  find "${BACKUP_DIR}" -maxdepth 1 -type f \
    \( -name 'x-ui-*.tar.gz' -o -name 'x-ui-*.tar.gz.sha256' \) \
    -mtime "+${RETENTION_DAYS}" -delete
}

trap cleanup EXIT
validate_environment
prepare_staging
backup_database
copy_configuration
write_package_list
write_manifest
create_archive
prune_expired
