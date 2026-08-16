#!/usr/bin/env bash
set -euo pipefail

readonly RUNTIME_CONFIG="/etc/default/vpn"
readonly MODE="${1:-}"

if [[ -s "${RUNTIME_CONFIG}" && -z "${VPN_SERVER_ADDRESS:-}" ]]; then
  # shellcheck disable=SC1090,SC1091 # Created by prepare and validated below.
  source "${RUNTIME_CONFIG}"
fi

readonly XUI_VERSION="${XUI_VERSION:-v3.6.0}"
readonly VPN_ADMIN_USER="${VPN_ADMIN_USER:-vpnadmin}"
readonly VPN_SERVER_ADDRESS="${VPN_SERVER_ADDRESS:-}"
readonly VPN_EXPECTED_EGRESS_IP="${VPN_EXPECTED_EGRESS_IP:-}"
readonly VPN_PANEL_PORT="${VPN_PANEL_PORT:-}"
readonly VPN_SUBSCRIPTION_PORT="${VPN_SUBSCRIPTION_PORT:-2096}"
readonly VPN_TUNNEL_PORT="${VPN_TUNNEL_PORT:-443}"
readonly VPN_TLS_SERVER_NAME="${VPN_TLS_SERVER_NAME:-}"
readonly VPN_CERTIFICATE_MODE="${VPN_CERTIFICATE_MODE:-domain}"
readonly VPN_CERTIFICATE_FILE="${VPN_CERTIFICATE_FILE:-}"
readonly VPN_CERTIFICATE_KEY_FILE="${VPN_CERTIFICATE_KEY_FILE:-}"
readonly VPN_ACME_HTTP_PORT="${VPN_ACME_HTTP_PORT:-80}"
readonly PANEL_ALLOWED_CIDR="${PANEL_ALLOWED_CIDR:-}"
readonly ADMIN_PUBLIC_KEY_FILE="${ADMIN_PUBLIC_KEY_FILE:-}"
readonly KEY_LOGIN_VERIFIED="${KEY_LOGIN_VERIFIED:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT
installer_path=""
temporary_path=""
admin_password_hash="${VPNADMIN_PASSWORD_HASH:-}"

# Removes only temporary files created by this deployment run.
cleanup() {
  if [[ -n "${installer_path}" ]]; then
    [[ "${installer_path}" == /tmp/3x-ui-install.* ]]
    [[ -f "${installer_path}" ]]
    rm -f -- "${installer_path}"
  fi

  if [[ -n "${temporary_path}" ]]; then
    [[ "${temporary_path}" == /tmp/x-ui-*.* ]]
    [[ -f "${temporary_path}" ]]
    rm -f -- "${temporary_path}"
  fi
}

# Rejects unsupported hosts and incomplete repository copies before changes.
validate_host() {
  [[ "${EUID}" -eq 0 ]]
  [[ "$(uname -m)" == "x86_64" ]]
  # shellcheck disable=SC1091 # This file is guaranteed by Ubuntu.
  source /etc/os-release
  [[ "${ID}" == "ubuntu" ]]
  [[ "${VERSION_ID}" == "24.04" ]]
  [[ -s "${REPO_ROOT}/scripts/backup.sh" ]]
  [[ -s "${REPO_ROOT}/scripts/renew-certificate.sh" ]]
  [[ -s "${REPO_ROOT}/ops/diagnose.sh" ]]
  [[ -s "${REPO_ROOT}/ops/systemd/x-ui-hardening.conf" ]]
}

# Validates one public TCP or UDP port used by the deployment.
validate_port() {
  local name="$1"
  local value="$2"
  [[ -n "${name}" ]]
  [[ "${value}" =~ ^[0-9]+$ ]]
  [[ "${value}" -ge 1 && "${value}" -le 65535 ]]
}

# Validates the common non-secret deployment values.
validate_configuration() {
  [[ "${MODE}" =~ ^(prepare|install|enable-operations|harden-ssh)$ ]]
  [[ "${VPN_ADMIN_USER}" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]
  [[ "${VPN_SERVER_ADDRESS}" =~ ^[A-Za-z0-9._:-]+$ ]]
  [[ "${VPN_EXPECTED_EGRESS_IP}" =~ ^[0-9A-Fa-f:.]+$ ]]
  [[ "${VPN_TLS_SERVER_NAME}" =~ ^[A-Za-z0-9.-]+$ ]]
  [[ "${VPN_CERTIFICATE_MODE}" == "domain" || "${VPN_CERTIFICATE_MODE}" == "ip" ]]
  [[ -z "${VPN_CERTIFICATE_FILE}" || "${VPN_CERTIFICATE_FILE}" =~ ^/[A-Za-z0-9._/-]+$ ]]
  [[ -z "${VPN_CERTIFICATE_KEY_FILE}" \
    || "${VPN_CERTIFICATE_KEY_FILE}" =~ ^/[A-Za-z0-9._/-]+$ ]]
  [[ -z "${PANEL_ALLOWED_CIDR}" || "${PANEL_ALLOWED_CIDR}" =~ ^[0-9A-Fa-f:./]+$ ]]
  validate_port "panel" "${VPN_PANEL_PORT}"
  validate_port "subscription" "${VPN_SUBSCRIPTION_PORT}"
  validate_port "tunnel" "${VPN_TUNNEL_PORT}"
  validate_port "ACME HTTP" "${VPN_ACME_HTTP_PORT}"
  [[ "${VPN_ACME_HTTP_PORT}" -eq 80 ]]
  [[ "${VPN_PANEL_PORT}" -ge 1024 ]]
  [[ "${VPN_SUBSCRIPTION_PORT}" -ge 1024 ]]
  [[ "${VPN_PANEL_PORT}" != "${VPN_SUBSCRIPTION_PORT}" ]]
  [[ "${VPN_PANEL_PORT}" != "${VPN_TUNNEL_PORT}" ]]
  [[ "${VPN_SUBSCRIPTION_PORT}" != "${VPN_TUNNEL_PORT}" ]]
}

# Validates the public key required to create the administrative account.
validate_prepare_inputs() {
  [[ -s "${ADMIN_PUBLIC_KEY_FILE}" ]]
  grep -Eq '^ssh-ed25519[[:space:]]' "${ADMIN_PUBLIC_KEY_FILE}"
  [[ "$(stat -c '%s' "${ADMIN_PUBLIC_KEY_FILE}")" -lt 1024 ]]
}

# Uses a supplied hash or securely prompts for the sudo password on the server.
resolve_admin_password_hash() {
  local password=""
  local confirmation=""
  if [[ -n "${admin_password_hash}" ]]; then
    [[ "${admin_password_hash}" == \$6\$* || "${admin_password_hash}" == \$y\$* ]]
    [[ "${#admin_password_hash}" -ge 40 ]]
    return
  fi

  read -r -s -p "New sudo password for ${VPN_ADMIN_USER}: " password </dev/tty
  printf '\n' >/dev/tty
  read -r -s -p 'Repeat the sudo password: ' confirmation </dev/tty
  printf '\n' >/dev/tty
  [[ "${#password}" -ge 12 ]]
  [[ "${password}" == "${confirmation}" ]]
  admin_password_hash="$(openssl passwd -6 "${password}")"
  password=""
  confirmation=""
  [[ "${admin_password_hash}" == \$6\$* ]]
  [[ "${#admin_password_hash}" -ge 40 ]]
}

# Installs the small set of host packages used by deployment and operations.
install_packages() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl fail2ban jq logrotate openssl sqlite3 ufw unattended-upgrades

  [[ -x "$(command -v curl)" ]]
  [[ -x "$(command -v sqlite3)" ]]
  [[ -z "$(dpkg --audit)" ]]
}

# Creates the sudo account with the supplied Ed25519 key and password hash.
create_admin_user() {
  id "${VPN_ADMIN_USER}" >/dev/null 2>&1 \
    || useradd --create-home --shell /bin/bash "${VPN_ADMIN_USER}"
  usermod --append --groups sudo "${VPN_ADMIN_USER}"
  usermod --password "${admin_password_hash}" "${VPN_ADMIN_USER}"
  install -d -o "${VPN_ADMIN_USER}" -g "${VPN_ADMIN_USER}" -m 700 \
    "/home/${VPN_ADMIN_USER}/.ssh"
  install -o "${VPN_ADMIN_USER}" -g "${VPN_ADMIN_USER}" -m 600 \
    "${ADMIN_PUBLIC_KEY_FILE}" "/home/${VPN_ADMIN_USER}/.ssh/authorized_keys"

  [[ "$(stat -c '%U:%G' "/home/${VPN_ADMIN_USER}/.ssh/authorized_keys")" \
    == "${VPN_ADMIN_USER}:${VPN_ADMIN_USER}" ]]
  [[ "$(stat -c '%a' "/home/${VPN_ADMIN_USER}/.ssh/authorized_keys")" == "600" ]]
}

# Persists non-secret values consumed by operations and later deployment phases.
write_runtime_configuration() {
  temporary_path="$(mktemp /tmp/x-ui-config.XXXXXX)"
  {
    printf 'VPN_ADMIN_USER=%q\n' "${VPN_ADMIN_USER}"
    printf 'VPN_SERVER_ADDRESS=%q\n' "${VPN_SERVER_ADDRESS}"
    printf 'VPN_EXPECTED_EGRESS_IP=%q\n' "${VPN_EXPECTED_EGRESS_IP}"
    printf 'VPN_PANEL_PORT=%q\n' "${VPN_PANEL_PORT}"
    printf 'VPN_SUBSCRIPTION_PORT=%q\n' "${VPN_SUBSCRIPTION_PORT}"
    printf 'VPN_TUNNEL_PORT=%q\n' "${VPN_TUNNEL_PORT}"
    printf 'VPN_TLS_SERVER_NAME=%q\n' "${VPN_TLS_SERVER_NAME}"
    printf 'VPN_CERTIFICATE_MODE=%q\n' "${VPN_CERTIFICATE_MODE}"
    printf 'VPN_CERTIFICATE_FILE=%q\n' "${VPN_CERTIFICATE_FILE}"
    printf 'VPN_CERTIFICATE_KEY_FILE=%q\n' "${VPN_CERTIFICATE_KEY_FILE}"
    printf 'VPN_ACME_HTTP_PORT=%q\n' "${VPN_ACME_HTTP_PORT}"
    printf 'PANEL_ALLOWED_CIDR=%q\n' "${PANEL_ALLOWED_CIDR}"
  } > "${temporary_path}"
  install -o root -g root -m 644 "${temporary_path}" "${RUNTIME_CONFIG}"

  [[ -s "${RUNTIME_CONFIG}" ]]
  [[ "$(grep -E '^VPN_PANEL_PORT=' "${RUNTIME_CONFIG}")" \
    == "VPN_PANEL_PORT=${VPN_PANEL_PORT}" ]]
}

# Applies a default-deny firewall with only the required public services.
configure_firewall() {
  ufw default deny incoming
  ufw default allow outgoing
  ufw limit 22/tcp
  ufw allow "${VPN_ACME_HTTP_PORT}/tcp"
  ufw allow "${VPN_TUNNEL_PORT}/udp"
  ufw allow "${VPN_SUBSCRIPTION_PORT}/tcp"

  if [[ -n "${PANEL_ALLOWED_CIDR}" ]]; then
    ufw allow from "${PANEL_ALLOWED_CIDR}" to any port "${VPN_PANEL_PORT}" proto tcp
  else
    ufw allow "${VPN_PANEL_PORT}/tcp"
  fi

  ufw --force enable
  [[ "$(ufw status | head -n 1)" == "Status: active" ]]
  ufw status | grep -q "${VPN_TUNNEL_PORT}/udp"
}

# Installs host policies and enables their services without hardening SSH yet.
configure_host_security() {
  install -o root -g root -m 644 "${REPO_ROOT}/ops/apt/20auto-upgrades" \
    /etc/apt/apt.conf.d/20auto-upgrades
  install -o root -g root -m 644 \
    "${REPO_ROOT}/ops/apt/52vpn-unattended-upgrades" \
    /etc/apt/apt.conf.d/52vpn-unattended-upgrades
  configure_firewall
  systemctl enable --now fail2ban unattended-upgrades

  [[ "$(systemctl is-active fail2ban)" == "active" ]]
  [[ "$(systemctl is-active unattended-upgrades)" == "active" ]]
}

# Installs the pinned official stable 3x-ui release when absent.
install_panel() {
  if [[ ! -x /usr/local/x-ui/x-ui ]]; then
    installer_path="$(mktemp /tmp/3x-ui-install.XXXXXX)"
    curl --fail --location --show-error \
      "https://raw.githubusercontent.com/MHSanaei/3x-ui/${XUI_VERSION}/install.sh" \
      --output "${installer_path}"
    bash "${installer_path}" "${XUI_VERSION}"
  fi

  [[ -x /usr/local/x-ui/x-ui ]]
  [[ "$(/usr/local/x-ui/x-ui -v | tail -n 1)" == "${XUI_VERSION#v}" ]]
}

# Installs versioned operational files without starting unconfigured health checks.
install_operations() {
  id x-ui-health >/dev/null 2>&1 \
    || useradd --system --no-create-home --shell /usr/sbin/nologin x-ui-health
  install -o root -g root -m 0750 "${REPO_ROOT}/scripts/render-tunnel-client.sh" \
    /usr/local/sbin/x-ui-render-health-client
  install -o root -g root -m 0750 "${REPO_ROOT}/scripts/backup.sh" \
    /usr/local/sbin/x-ui-backup
  install -o root -g root -m 0750 "${REPO_ROOT}/scripts/restore.sh" \
    /usr/local/sbin/x-ui-restore
  install -o root -g root -m 0750 "${REPO_ROOT}/scripts/renew-certificate.sh" \
    /usr/local/sbin/x-ui-renew-certificate
  install -o root -g root -m 0750 "${REPO_ROOT}/ops/diagnose.sh" \
    /usr/local/sbin/x-ui-diagnose
  install -d -o root -g root -m 755 /etc/systemd/system/x-ui.service.d \
    /etc/systemd/journald.conf.d
  install -o root -g root -m 644 "${REPO_ROOT}/ops/systemd/x-ui-hardening.conf" \
    /etc/systemd/system/x-ui.service.d/hardening.conf
  install -o root -g root -m 644 "${REPO_ROOT}/ops/systemd/"x-ui-*.service \
    /etc/systemd/system/
  install -o root -g root -m 644 "${REPO_ROOT}/ops/systemd/"x-ui-*.timer \
    /etc/systemd/system/
  install -o root -g root -m 644 "${REPO_ROOT}/ops/default/x-ui" /etc/default/x-ui
  install -o root -g root -m 644 "${REPO_ROOT}/ops/journald/vpn-limits.conf" \
    /etc/systemd/journald.conf.d/vpn-limits.conf
  install -o root -g root -m 644 "${REPO_ROOT}/ops/logrotate/x-ui" \
    /etc/logrotate.d/x-ui
  install -o root -g root -m 600 "${REPO_ROOT}/ops/fail2ban/3x-ipl.conf" \
    /etc/fail2ban/jail.d/3x-ipl.conf
  systemctl daemon-reload
  systemctl restart fail2ban

  [[ -x /usr/local/sbin/x-ui-restore ]]
  [[ -x /usr/local/sbin/x-ui-renew-certificate ]]
  [[ -f /etc/systemd/system/x-ui-backup.timer ]]
}

# Renders the health client and enables scheduled operations after panel setup.
enable_operations() {
  [[ -s /etc/x-ui/health-client.env ]]
  [[ -x /usr/local/sbin/x-ui-render-health-client ]]
  [[ -n "${VPN_CERTIFICATE_FILE}" ]]
  [[ -n "${VPN_CERTIFICATE_KEY_FILE}" ]]
  /usr/local/sbin/x-ui-render-health-client
  /usr/local/x-ui/bin/xray-linux-amd64 run -test \
    -config /etc/x-ui/tunnel-health-client.json
  install -o root -g root -m 644 "${REPO_ROOT}/ops/systemd/x-ui-health.conf" \
    /etc/systemd/system/x-ui.service.d/health.conf
  systemctl daemon-reload
  systemctl enable --now x-ui-health.service x-ui-backup.timer

  /usr/local/sbin/x-ui-renew-certificate
  systemctl enable --now x-ui-cert-renew.timer

  systemctl restart x-ui
  systemctl start x-ui-backup.service
  systemctl is-active --quiet x-ui
  systemctl is-active --quiet x-ui-health
}

# Disables password and root SSH only after a separate key login was verified.
harden_ssh() {
  [[ "${KEY_LOGIN_VERIFIED}" == "verified" ]]
  [[ -s "/home/${VPN_ADMIN_USER}/.ssh/authorized_keys" ]]
  temporary_path="$(mktemp /tmp/x-ui-ssh.XXXXXX)"
  sed "s/__VPN_ADMIN_USER__/${VPN_ADMIN_USER}/g" \
    "${REPO_ROOT}/ops/ssh/00-vpn-hardening.conf" > "${temporary_path}"
  install -o root -g root -m 644 "${temporary_path}" \
    /etc/ssh/sshd_config.d/00-vpn-hardening.conf
  sshd -t
  systemctl reload ssh

  sshd -T | grep -Fxq 'passwordauthentication no'
  sshd -T | grep -Fxq 'permitrootlogin no'
  sshd -T | grep -Fxq 'x11forwarding no'
}

trap cleanup EXIT
validate_host
validate_configuration

case "${MODE}" in
  prepare)
    validate_prepare_inputs
    install_packages
    resolve_admin_password_hash
    create_admin_user
    write_runtime_configuration
    configure_host_security
    printf 'Prepare complete. Verify a separate key login before harden-ssh.\n'
    ;;
  install)
    install_panel
    install_operations
    printf 'Install complete. Configure 3x-ui before enable-operations.\n'
    ;;
  enable-operations)
    enable_operations
    printf 'Health checks, backups, and verified certificate renewal are enabled.\n'
    ;;
  harden-ssh)
    harden_ssh
    printf 'SSH hardening complete.\n'
    ;;
esac
