#!/usr/bin/env bash
set -Eeuo pipefail

readonly RUNTIME_CONFIG="${RUNTIME_CONFIG:-/etc/default/vpn}"

if [[ -s "${RUNTIME_CONFIG}" ]]; then
  # shellcheck disable=SC1090,SC1091 # Created by deploy.sh and validated below.
  source "${RUNTIME_CONFIG}"
fi

readonly ACME_HOME="${ACME_HOME:-/root/.acme.sh}"
readonly ACME_BIN="${ACME_BIN:-${ACME_HOME}/acme.sh}"
readonly CERTIFICATE_LOCK_FILE="${CERTIFICATE_LOCK_FILE:-/run/x-ui-cert-renew.lock}"
readonly X_UI_SERVICE="${X_UI_SERVICE:-x-ui}"
readonly VPN_TLS_SERVER_NAME="${VPN_TLS_SERVER_NAME:-}"
readonly VPN_CERTIFICATE_MODE="${VPN_CERTIFICATE_MODE:-domain}"
readonly VPN_CERTIFICATE_FILE="${VPN_CERTIFICATE_FILE:-}"
readonly VPN_CERTIFICATE_KEY_FILE="${VPN_CERTIFICATE_KEY_FILE:-}"
readonly VPN_ACME_HTTP_PORT="${VPN_ACME_HTTP_PORT:-80}"
readonly MINIMUM_VALIDITY_SECONDS="${MINIMUM_VALIDITY_SECONDS:-172800}"

# Rejects unsafe or incomplete values before certificate state is changed.
validate_configuration() {
  [[ "${EUID}" -eq 0 ]]
  [[ -x "${ACME_BIN}" ]]
  [[ "${VPN_CERTIFICATE_MODE}" == "domain" || "${VPN_CERTIFICATE_MODE}" == "ip" ]]
  [[ "${VPN_TLS_SERVER_NAME}" =~ ^[A-Za-z0-9.:-]+$ ]]
  [[ "${VPN_CERTIFICATE_FILE}" =~ ^/[A-Za-z0-9._/-]+$ ]]
  [[ "${VPN_CERTIFICATE_KEY_FILE}" =~ ^/[A-Za-z0-9._/-]+$ ]]
  [[ "${VPN_ACME_HTTP_PORT}" =~ ^[0-9]+$ ]]
  [[ "${VPN_ACME_HTTP_PORT}" -ge 1 && "${VPN_ACME_HTTP_PORT}" -le 65535 ]]
  [[ "${MINIMUM_VALIDITY_SECONDS}" =~ ^[0-9]+$ ]]
  [[ "${MINIMUM_VALIDITY_SECONDS}" -ge 86400 ]]
  [[ "${X_UI_SERVICE}" =~ ^[A-Za-z0-9@_.-]+$ ]]
  command -v flock >/dev/null
  command -v openssl >/dev/null
}

# Returns success only when acme.sh knows how to renew the configured identity.
certificate_is_registered() {
  [[ -x "${ACME_BIN}" ]]
  [[ -n "${VPN_TLS_SERVER_NAME}" ]]

  "${ACME_BIN}" --list \
    | awk -v name="${VPN_TLS_SERVER_NAME}" '$1 == name {print $1}' \
    | grep -Fxq "${VPN_TLS_SERVER_NAME}"
}

# Returns success only when the installed certificate is valid beyond the safety window.
certificate_is_current() {
  [[ -n "${VPN_CERTIFICATE_FILE}" ]]
  [[ "${MINIMUM_VALIDITY_SECONDS}" =~ ^[0-9]+$ ]]
  [[ -f "${VPN_CERTIFICATE_FILE}" ]] || return 1

  openssl x509 -in "${VPN_CERTIFICATE_FILE}" -noout \
    -checkend "${MINIMUM_VALIDITY_SECONDS}" >/dev/null
}

# Confirms that the certificate is valid for the configured domain or public IP.
certificate_matches_configured_identity() {
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

# Confirms that the installed private key belongs to the installed certificate.
certificate_matches_private_key() {
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

# Issues and installs a replacement using the repository's standalone HTTP contract.
issue_and_install_certificate() {
  local -a issue_arguments=(
    --issue
    -d "${VPN_TLS_SERVER_NAME}"
    --standalone
    --server letsencrypt
    --httpport "${VPN_ACME_HTTP_PORT}"
    --force
  )
  [[ -x "${ACME_BIN}" ]]
  [[ "${VPN_CERTIFICATE_MODE}" == "domain" || "${VPN_CERTIFICATE_MODE}" == "ip" ]]

  if [[ "${VPN_CERTIFICATE_MODE}" == "ip" ]]; then
    issue_arguments+=(--certificate-profile shortlived --days 6)
  fi

  "${ACME_BIN}" --set-default-ca --server letsencrypt --force
  "${ACME_BIN}" "${issue_arguments[@]}"
  "${ACME_BIN}" --installcert -d "${VPN_TLS_SERVER_NAME}" \
    --key-file "${VPN_CERTIFICATE_KEY_FILE}" \
    --fullchain-file "${VPN_CERTIFICATE_FILE}" \
    --reloadcmd "systemctl restart ${X_UI_SERVICE}"

  chmod 600 "${VPN_CERTIFICATE_KEY_FILE}"
  chmod 644 "${VPN_CERTIFICATE_FILE}"
}

# Runs normal ARI-aware renewal and repairs missing or unusable certificate state.
main() {
  local recovery_required=false
  [[ -n "${CERTIFICATE_LOCK_FILE}" ]]
  [[ "${CERTIFICATE_LOCK_FILE}" == /* ]]
  validate_configuration

  exec 9>"${CERTIFICATE_LOCK_FILE}"
  flock -n 9

  if certificate_is_registered; then
    "${ACME_BIN}" --cron --home "${ACME_HOME}"
  else
    recovery_required=true
  fi

  if ! certificate_is_current \
    || ! certificate_matches_configured_identity \
    || ! certificate_matches_private_key; then
    recovery_required=true
  fi

  if [[ "${recovery_required}" == true ]]; then
    issue_and_install_certificate
  fi

  certificate_is_registered
  certificate_is_current
  certificate_matches_configured_identity
  certificate_matches_private_key
  printf 'Certificate renewal check passed for %s.\n' "${VPN_TLS_SERVER_NAME}"
}

main
