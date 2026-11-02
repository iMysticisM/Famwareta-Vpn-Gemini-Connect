#!/usr/bin/env bash
# ==============================================================================
# FamVpnGemini - Seamless In-Place Updater
# Preserves data/, accounts, credentials, and custom config.json
# ==============================================================================
set -euo pipefail

INSTALL_DIR="/opt/famvpngemini"
DATA_DIR="$INSTALL_DIR/data"
SERVICE_NAME="famvpngemini"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[Error] Update script must be run as root (sudo bash update.sh)${NC}" >&2
    exit 1
fi

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}             FamVpnGemini In-Place Updater           ${NC}"
echo -e "${CYAN}======================================================${NC}"

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)
        CORE_ARCH="amd64"
        ;;
    aarch64|arm64)
        CORE_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}[Error] Unsupported architecture: $ARCH${NC}" >&2
        exit 1
        ;;
esac

echo -e "${YELLOW}[1/3] Backing up existing credentials and config...${NC}"
BACKUP_DIR="$INSTALL_DIR/backups/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
if [ -d "$DATA_DIR" ]; then
    cp -r "$DATA_DIR" "$BACKUP_DIR/"
    echo -e "${GREEN}✓ Backup saved to $BACKUP_DIR${NC}"
fi

echo -e "${YELLOW}[2/3] Updating famvpngemini-core binary...${NC}"
TEMP_DIR=$(mktemp -d)
DOWNLOAD_URL="https://github.com/armanlife/firefox-vpn-client/releases/latest/download/firefox-vpn-core-linux-${CORE_ARCH}.tar.gz"

if curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$TEMP_DIR"; then
    systemctl stop "$SERVICE_NAME" || true
    mv "$TEMP_DIR/firefox-vpn-core" "$INSTALL_DIR/famvpngemini-core"
    chmod +x "$INSTALL_DIR/famvpngemini-core"
    rm -rf "$TEMP_DIR"
    echo -e "${GREEN}✓ Core binary updated.${NC}"
else
    echo -e "${RED}[Error] Failed to download update binary. Keeping existing version.${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${YELLOW}[3/3] Restarting service...${NC}"
systemctl daemon-reload
systemctl restart "$SERVICE_NAME"

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}  ✓ FamVpnGemini Update Completed Successfully!      ${NC}"
echo -e "${GREEN}======================================================${NC}"
systemctl is-active --quiet "$SERVICE_NAME" && echo -e "Service Status: ${GREEN}Active (Running)${NC}" || echo -e "Service Status: ${RED}Check logs with fam-vpn logs${NC}"
