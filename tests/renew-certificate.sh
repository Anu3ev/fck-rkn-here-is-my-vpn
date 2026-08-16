#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
test_directory=""

# Removes only the isolated fixture directory created by this test.
cleanup() {
  [[ -z "${test_directory}" ]] && return
  [[ "${test_directory}" == /tmp/vpn-certificate-test.* ]]
  [[ -d "${test_directory}" ]]
  rm -rf -- "${test_directory}"
}

# Creates a valid short-lived IP certificate and a controllable fake ACME client.
write_fixtures() {
  local acme_bin="$1"
  local runtime_file="$2"
  [[ "${EUID}" -eq 0 ]]
  [[ -d "${test_directory}" ]]

  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout "${test_directory}/issued.key" \
    -out "${test_directory}/issued.pem" \
    -days 7 -subj '/CN=198.51.100.10' \
    -addext 'subjectAltName=IP:198.51.100.10' >/dev/null 2>&1

  cat > "${runtime_file}" <<EOF
VPN_TLS_SERVER_NAME=198.51.100.10
VPN_CERTIFICATE_MODE=ip
VPN_CERTIFICATE_FILE=${test_directory}/live/fullchain.pem
VPN_CERTIFICATE_KEY_FILE=${test_directory}/live/privkey.pem
VPN_ACME_HTTP_PORT=8080
EOF

  cat > "${acme_bin}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_ACME_LOG}"

if [[ "${1:-}" == "--list" ]]; then
  printf 'Main_Domain KeyLength\n'
  [[ -f "${FAKE_ACME_STATE}" ]] && printf '198.51.100.10 ec-256\n'
  exit 0
fi

if [[ "${1:-}" == "--issue" ]]; then
  touch "${FAKE_ACME_STATE}"
  exit 0
fi

if [[ "${1:-}" != "--installcert" ]]; then
  exit 0
fi

key_file=''
fullchain_file=''
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --key-file)
      key_file="$2"
      shift 2
      ;;
    --fullchain-file)
      fullchain_file="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[[ -n "${key_file}" ]]
[[ -n "${fullchain_file}" ]]
install -D -m 600 "${FAKE_ISSUED_KEY}" "${key_file}"
install -D -m 644 "${FAKE_ISSUED_CERT}" "${fullchain_file}"
EOF
  chmod 700 "${acme_bin}"

  [[ -s "${runtime_file}" ]]
  [[ -x "${acme_bin}" ]]
}

# Proves that missing renewal state is recovered and later checks use normal cron.
assert_recovery_contract() {
  local acme_bin="$1"
  local runtime_file="$2"
  local log_file="${test_directory}/acme.log"
  [[ -x "${acme_bin}" ]]
  [[ -s "${runtime_file}" ]]

  export FAKE_ACME_LOG="${log_file}"
  export FAKE_ACME_STATE="${test_directory}/registered"
  export FAKE_ISSUED_KEY="${test_directory}/issued.key"
  export FAKE_ISSUED_CERT="${test_directory}/issued.pem"

  RUNTIME_CONFIG="${runtime_file}" \
    ACME_HOME="${test_directory}/acme" \
    ACME_BIN="${acme_bin}" \
    CERTIFICATE_LOCK_FILE="${test_directory}/renew.lock" \
    bash "${REPO_ROOT}/scripts/renew-certificate.sh"

  [[ -f "${FAKE_ACME_STATE}" ]]
  [[ "$(stat -c '%a' "${test_directory}/live/privkey.pem")" == "600" ]]
  [[ "$(stat -c '%a' "${test_directory}/live/fullchain.pem")" == "644" ]]
  grep -Fq -- '--certificate-profile shortlived --days 6' "${log_file}"
  grep -Fq -- '--reloadcmd systemctl restart x-ui' "${log_file}"

  : > "${log_file}"
  RUNTIME_CONFIG="${runtime_file}" \
    ACME_HOME="${test_directory}/acme" \
    ACME_BIN="${acme_bin}" \
    CERTIFICATE_LOCK_FILE="${test_directory}/renew.lock" \
    bash "${REPO_ROOT}/scripts/renew-certificate.sh"

  grep -Fq -- '--cron' "${log_file}"
  ! grep -Fq -- '--issue' "${log_file}"
}

# Runs the recovery scenario through the same root boundary used by systemd.
main() {
  [[ "${EUID}" -eq 0 ]]
  command -v openssl >/dev/null
  test_directory="$(mktemp -d /tmp/vpn-certificate-test.XXXXXX)"
  local acme_bin="${test_directory}/acme.sh"
  local runtime_file="${test_directory}/vpn.env"

  write_fixtures "${acme_bin}" "${runtime_file}"
  assert_recovery_contract "${acme_bin}" "${runtime_file}"
}

trap cleanup EXIT
main
