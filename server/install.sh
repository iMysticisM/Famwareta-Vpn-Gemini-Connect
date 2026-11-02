#!/usr/bin/env bash
# ==============================================================================
# FamVpnGemini - All-in-One Automated Installer & Configurator
# Compatible with Ubuntu 24.04 / 22.04, Debian 12 / 11
# ==============================================================================
set -euo pipefail

INSTALL_DIR="/opt/famvpngemini"
DATA_DIR="$INSTALL_DIR/data"
SERVICE_NAME="famvpngemini"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

clear || true
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   🚀 FamVpnGemini - Clean Egress Pool & Panel Installer       ${NC}"
echo -e "${CYAN}================================================================${NC}"

# 1. Root check
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[Error] This script must be run as root. Run with: sudo bash install.sh${NC}" >&2
    exit 1
fi

# 2. Architecture detection
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

echo -e "${YELLOW}[1/6] Preparing directories at ${INSTALL_DIR}...${NC}"
mkdir -p "$DATA_DIR"
mkdir -p "$INSTALL_DIR/backups"

echo -e "${YELLOW}[2/6] Downloading latest FamVpnGemini Core binary ($CORE_ARCH)...${NC}"
DOWNLOAD_URL="https://github.com/armanlife/firefox-vpn-client/releases/latest/download/firefox-vpn-core-linux-${CORE_ARCH}.tar.gz"
TEMP_DIR=$(mktemp -d)

if ! curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$TEMP_DIR"; then
    echo -e "${RED}[Error] Failed to download or unpack core binary.${NC}" >&2
    rm -rf "$TEMP_DIR"
    exit 1
fi

mv "$TEMP_DIR/firefox-vpn-core" "$INSTALL_DIR/famvpngemini-core"
chmod +x "$INSTALL_DIR/famvpngemini-core"
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓ Core binary installed successfully.${NC}"

echo -e "${YELLOW}[3/6] Generating default config and firewall presets...${NC}"
CONFIG_FILE="$DATA_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
  "proxy": {
    "listen": "127.0.0.1:10810",
    "country": "",
    "transport": "h2",
    "upstream_connections": 2,
    "max_connections": 512,
    "idle_sleep": "0s"
  },
  "accounts": {
    "switch_threshold_percent": 95,
    "order": []
  },
  "dashboard": {
    "enabled": true,
    "listen": "127.0.0.1:10820"
  },
  "routing": {
    "enabled": false,
    "region": "",
    "direct": [
      "geosite:youtube",
      "geosite:instagram",
      "geosite:netflix",
      "geosite:tiktok",
      "domain:googlevideo.com",
      "domain:cdninstagram.com"
    ],
    "block": [
      "geosite:category-porn",
      "geosite:torrent",
      "domain:bittorrent.com"
    ]
  },
  "logging": {
    "verbose": false
  }
}
EOF
    echo -e "${GREEN}✓ Default config.json created.${NC}"
else
    echo -e "${CYAN}Existing config.json preserved.${NC}"
fi

echo -e "${YELLOW}[4/6] Configuring Anti-DPI security & randomized secret path...${NC}"
SECRET_PATH="fam-$(openssl rand -hex 6 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom | head -c 12)"
PANEL_USER="admin"
PANEL_PASS="$(openssl rand -base64 12 2>/dev/null || tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)"

SECRET_RECORD="$INSTALL_DIR/.panel_secret"
cat > "$SECRET_RECORD" << EOF
PANEL_SECRET_PATH="${SECRET_PATH}"
PANEL_USER="${PANEL_USER}"
PANEL_PASS="${PANEL_PASS}"
EOF

# Setup password hash for dashboard inside config
"$INSTALL_DIR/famvpngemini-core" -setup-server "$PANEL_USER" -data-dir "$DATA_DIR" >/dev/null 2>&1 || true

echo -e "${YELLOW}[5/6] Creating systemd service (${SERVICE_NAME}.service)...${NC}"
cat > "$UNIT_FILE" << EOF
[Unit]
Description=FamVpnGemini Core Service - Clean Egress Pool
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/famvpngemini-core -data-dir ${DATA_DIR}
Restart=always
RestartSec=5
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo -e "${YELLOW}[6/6] Installing CLI management commands (fam-vpn)...${NC}"
cp "$INSTALL_DIR/fam-vpn" "/usr/local/bin/fam-vpn" 2>/dev/null || true
if [ ! -f "/usr/local/bin/fam-vpn" ]; then
    # Fallback copy
    curl -fsSL "https://raw.githubusercontent.com/.../server/fam-vpn" -o "/usr/local/bin/fam-vpn" 2>/dev/null || true
fi
chmod +x "/usr/local/bin/fam-vpn" 2>/dev/null || true
ln -sf "/usr/local/bin/fam-vpn" "/usr/local/bin/famvpngemini" 2>/dev/null || true

# Generate Nginx reverse-proxy helper block
NGINX_SNIPPET="$INSTALL_DIR/nginx-famvpngemini.conf"
cat > "$NGINX_SNIPPET" << EOF
# Add this inside your fake domain's server { ... } block in Nginx:
location /${SECRET_PATH}/ {
    proxy_pass http://127.0.0.1:10820/app/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_buffering off;
}

location /${SECRET_PATH}/api/ {
    proxy_pass http://127.0.0.1:10820/api/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
}
EOF

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}   ✓ FamVpnGemini Installation Completed Successfully!          ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""
echo -e "${BOLD}1. Port Information:${NC}"
echo -e "   - SOCKS5 Egress:     ${CYAN}127.0.0.1:10810${NC} (Use in Hiddify / Marzban / 3X-UI)"
echo -e "   - Dashboard (Local): ${CYAN}127.0.0.1:10820${NC} (Protected on loopback)"
echo ""
echo -e "${BOLD}2. Web Dashboard Access & Anti-DPI Protection:${NC}"
echo -e "   - Secret Path:       ${GREEN}/${SECRET_PATH}/${NC}"
echo -e "   - Dashboard User:    ${YELLOW}${PANEL_USER}${NC}"
echo -e "   - Dashboard Pass:    ${YELLOW}${PANEL_PASS}${NC}"
echo ""
echo -e "${BOLD}3. How to access your dashboard safely without IP leaks:${NC}"
echo -e "   ${CYAN}روش الف (پیشنهادی - ۱۰۰٪ ضد DPI بدون باز کردن پورت):${NC}"
echo -e "   روی سیستم خود در ترمینال یا PowerShell این دستور را بزنید:"
echo -e "   ${GREEN}ssh -L 10820:127.0.0.1:10820 root@YOUR_SERVER_IP${NC}"
echo -e "   سپس در مرورگر خود این آدرس را باز کنید:"
echo -e "   ${GREEN}http://127.0.0.1:10820/app/${NC}"
echo ""
echo -e "   ${CYAN}روش ب (اتصال از طریق دامنه فیک با Cloudflare CDN):${NC}"
echo -e "   کد موجود در فایل ${YELLOW}${NGINX_SNIPPET}${NC} را داخل بلاک Nginx دامنه خود بگذارید تا با آدرس زیر باز شود:"
echo -e "   ${GREEN}https://your-fake-domain.com/${SECRET_PATH}/${NC}"
echo ""
echo -e "${BOLD}4. دستورات مدیریت سریع (CLI):${NC}"
echo -e "   - ${CYAN}fam-vpn add${NC}     -> افزودن اکانت جدید به استخر مولتی‌اکانت"
echo -e "   - ${CYAN}fam-vpn list${NC}    -> مشاهده حجم باقی‌مانده و اکانت‌های فعال"
echo -e "   - ${CYAN}fam-vpn test${NC}    -> تست پینگ و اطمینان از ای‌پی تمیز Fastly"
echo -e "   - ${CYAN}fam-vpn update${NC}  -> آپدیت خودکار به آخرین نسخه بدون حذف اکانت‌ها"
echo -e "   - ${CYAN}fam-vpn panel${NC}   -> مشاهده مجدد اطلاعات و رمز پنل"
echo ""
