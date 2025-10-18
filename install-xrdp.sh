#!/usr/bin/env bash
set -euo pipefail

# install-xrdp.sh
# Simple idempotent installer: XFCE4 + xrdp + firefox (tries firefox-esr first)
# Usage: bash <(curl -s <raw-url>)   OR   sudo ./install-xrdp.sh

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { printf "${GREEN}=> %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}!! %s${NC}\n" "$*"; }
err()  { printf "${RED}ERROR: %s${NC}\n" "$*" >&2; }

# detect distro (only Debian/Ubuntu-like)
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "${ID,,}" in
    ubuntu|debian|linuxmint|pop|elementary) ;;
    *)
      err "This script is for Debian/Ubuntu based systems. Detected: $ID"
      exit 1
      ;;
  esac
else
  err "/etc/os-release not found. Can't detect distro."
  exit 1
fi

# ensure we have sudo if not root
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    REAL_USER="${SUDO_USER:-$(whoami)}"
  else
    err "Run as root or install sudo."
    exit 1
  fi
else
  SUDO=""
  REAL_USER="${SUDO_USER:-$(whoami)}"
fi

export DEBIAN_FRONTEND=noninteractive

log "Updating package lists..."
$SUDO apt-get update -y

log "Installing Firefox (try firefox-esr then firefox)..."
if $SUDO apt-get install -y firefox-esr 2>/dev/null; then
  log "Installed firefox-esr"
else
  warn "firefox-esr not available, trying firefox package..."
  $SUDO apt-get install -y firefox || warn "Failed to install firefox via apt. Continue anyway."
fi

log "Upgrading packages (safe)..."
$SUDO apt-get update -y
$SUDO apt-get upgrade -y

log "Installing XFCE4, xfce4-goodies and xrdp..."
$SUDO apt-get install -y xfce4 xfce4-goodies xrdp

# configure .xsession for the real user
USER_HOME="$(eval echo ~${REAL_USER})"
XSESSION_FILE="${USER_HOME}/.xsession"

if [ -f "${XSESSION_FILE}" ]; then
  log ".xsession already exists at ${XSESSION_FILE}"
else
  log "Writing startxfce4 to ${XSESSION_FILE}"
  echo "startxfce4" | $SUDO tee "${XSESSION_FILE}" >/dev/null
  $SUDO chown "${REAL_USER}:${REAL_USER}" "${XSESSION_FILE}" || warn "Couldn't chown ${XSESSION_FILE}"
  $SUDO chmod 644 "${XSESSION_FILE}" || true
fi

log "Enabling and restarting xrdp service..."
$SUDO systemctl enable xrdp --now
$SUDO systemctl restart xrdp

log "Done! XRDP should be running."

cat <<EOF

✅ Installation finished.

➡️ Connect via RDP to port 3389 (default).
➡️ Username: ${REAL_USER}
➡️ Check status: sudo systemctl status xrdp

Notes:
- If you run this from the GitHub raw URL, it downloads and runs directly.
- Always review scripts before running: curl -O <raw-url> && less install-xrdp.sh
- On some Ubuntu versions firefox is a snap package; firefox-esr may not be available.

EOF
