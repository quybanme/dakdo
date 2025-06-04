#!/bin/bash

# ──────────────── THÔNG TIN ────────────────
DAKDO_VERSION="1.0"
WWW_DIR="/var/www"
EMAIL="admin@dakdo.vn"

# ──────────────── MÀU SẮC ────────────────
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

# ──────────────── KIỂM TRA DOMAIN ────────────────
check_domain() {
    DOMAIN="$1"
    DOMAIN_IP=$(dig +short "$DOMAIN" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    SERVER_IP=$(curl -s ifconfig.me)
    if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
        echo -e "${GREEN}✔ Domain $DOMAIN đã trỏ đúng IP ($SERVER_IP)${NC}"
        return 0
    else
        echo -e "${RED}✘ Domain $DOMAIN chưa trỏ về VPS (IP hiện tại: $SERVER_IP)${NC}"
        return 1
    fi
}

# ──────────────── CÀI ĐẶT DAKDO ────────────────
install_base() {
    echo -e "${GREEN}🔧 Cài đặt Nginx, Certbot và công cụ hỗ trợ...${NC}"
    apt update -y
    apt install nginx certbot python3-certbot-nginx zip unzip curl dnsutils -y
    systemctl enable nginx
    systemctl start nginx
}

# ──────────────── THÊM WEBSITE ────────────────
add_website() {
    read -p "🌐 Nhập domain cần thêm: " DOMAIN
    check_domain "$DOMAIN" || exit 1

    SITE_DIR="$WWW_DIR/$DOMAIN"
    mkdir -p "$SITE_DIR"
    echo "<h1>DAKDO - Website $DOMAIN hoạt động!</h1>" > "$SITE_DIR/index.html"

    # Tạo config Nginx
    CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
    cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $SITE_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    ln -s "$CONFIG_FILE" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx

    echo -e "${GREEN}✅ Website $DOMAIN đã được tạo!${NC}"

    # SSL
    read -p "🔐 Cài SSL cho $DOMAIN? (y/n): " SSL_CONFIRM
    if [[ "$SSL_CONFIRM" == "y" ]]; then
        certbot --nginx --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d www.$DOMAIN
        echo -e "${GREEN}🔒 SSL đã cài thành công cho $DOMAIN${NC}"
    fi
}

# ──────────────── BACKUP WEBSITE ────────────────
backup_website() {
    read -p "💾 Nhập domain cần backup: " DOMAIN
    ZIP_FILE="${DOMAIN}_backup_$(date +%F).zip"
    zip -r "$ZIP_FILE" "$WWW_DIR/$DOMAIN"
    echo -e "${GREEN}✅ Backup hoàn tất: $ZIP_FILE${NC}"
}

# ──────────────── XÓA WEBSITE ────────────────
remove_website() {
    read -p "⚠ Nhập domain cần xoá: " DOMAIN
    rm -rf "$WWW_DIR/$DOMAIN"
    rm -f "/etc/nginx/sites-enabled/$DOMAIN"
    rm -f "/etc/nginx/sites-available/$DOMAIN"
    nginx -t && systemctl reload nginx
    echo -e "${RED}🗑 Website $DOMAIN đã bị xoá${NC}"
}

# ──────────────── THÔNG TIN HỆ THỐNG ────────────────
info_dakdo() {
    echo "📦 DAKDO Web Manager v$DAKDO_VERSION"
    echo "🌍 IP VPS: $(curl -s ifconfig.me)"
    echo "📁 Web Root: $WWW_DIR"
    echo "📧 Email SSL: $EMAIL"
}

# ──────────────── MENU CHÍNH ────────────────
menu_dakdo() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════╗"
    echo -e "║       DAKDO WEB MANAGER v$DAKDO_VERSION    ║"
    echo -e "╚══════════════════════════════════╝${NC}"
    echo "1. Cài đặt DAKDO (Nginx + SSL tool)"
    echo "2. Thêm Website HTML mới"
    echo "3. Backup Website"
    echo "4. Xoá Website"
    echo "5. Kiểm tra Domain"
    echo "6. Thông tin hệ thống"
    echo "7. Thoát"
    read -p "→ Chọn thao tác (1-7): " CHOICE

    case $CHOICE in
        1) install_base ;;
        2) add_website ;;
        3) backup_website ;;
        4) remove_website ;;
        5) read -p "🌐 Nhập domain để kiểm tra: " DOMAIN && check_domain "$DOMAIN" ;;
        6) info_dakdo ;;
        7) exit 0 ;;
        *) echo "❗ Lựa chọn không hợp lệ" ;;
    esac
}

# ──────────────── LẶP MENU ────────────────
while true; do
    menu_dakdo
    read -p "Nhấn Enter để tiếp tục..." pause
done
