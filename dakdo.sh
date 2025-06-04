#!/bin/bash

# DAKDO v1.1 – Web Manager for HTML + SSL (Upgraded)
# Author: @quybanme – https://github.com/quybanme

DAKDO_VERSION="1.1"
WWW_DIR="/var/www"
EMAIL="admin@dakdo.vn"
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

# Ensure required directories
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

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

install_base() {
    if command -v nginx > /dev/null; then
        echo -e "${GREEN}✅ Nginx đã được cài. Bỏ qua bước cài đặt.${NC}"
    else
        echo -e "${GREEN}🔧 Cài đặt Nginx, Certbot và công cụ hỗ trợ...${NC}"
        apt update -y
        apt install nginx certbot python3-certbot-nginx zip unzip curl dnsutils -y
        systemctl enable nginx
        systemctl start nginx
    fi

    # Setup auto-renew SSL
    if ! crontab -l | grep -q 'certbot renew'; then
        (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet") | crontab -
        echo "✅ Đã thêm cron tự động gia hạn SSL"
    fi
}

add_website() {
    read -p "🌐 Nhập domain cần thêm: " DOMAIN
    check_domain "$DOMAIN" || exit 1
    SITE_DIR="$WWW_DIR/$DOMAIN"
    mkdir -p "$SITE_DIR"
    if [ ! -f "$SITE_DIR/index.html" ]; then
        echo "<h1>DAKDO - Website $DOMAIN hoạt động!</h1>" > "$SITE_DIR/index.html"
    fi

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

    [ -L /etc/nginx/sites-enabled/$DOMAIN ] || ln -s "$CONFIG_FILE" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    echo -e "${GREEN}✅ Website $DOMAIN đã được tạo!${NC}"

    read -p "🔐 Cài SSL cho $DOMAIN? (y/n): " SSL_CONFIRM
    if [[ "$SSL_CONFIRM" == "y" ]]; then
        certbot --nginx --redirect --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d www.$DOMAIN
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}🔒 SSL đã cài thành công cho $DOMAIN${NC}"
        else
            echo -e "${RED}❌ Cài SSL thất bại. Vui lòng kiểm tra cấu hình hoặc kết nối.${NC}"
        fi
    fi
}

backup_website() {
    read -p "💾 Nhập domain cần backup: " DOMAIN
    ZIP_FILE="${DOMAIN}_backup_$(date +%F).zip"
    zip -r "$ZIP_FILE" "$WWW_DIR/$DOMAIN"
    echo -e "${GREEN}✅ Backup hoàn tất tại: $(realpath "$ZIP_FILE")${NC}"
}

remove_website() {
    read -p "⚠ Nhập domain cần xoá: " DOMAIN
    rm -rf "$WWW_DIR/$DOMAIN"
    rm -f "/etc/nginx/sites-enabled/$DOMAIN"
    rm -f "/etc/nginx/sites-available/$DOMAIN"
    nginx -t && systemctl reload nginx
    echo -e "${RED}🗑 Website $DOMAIN đã bị xoá${NC}"
}

list_websites() {
    echo -e "\n🌐 Danh sách website đã cài:"
    ls /etc/nginx/sites-available 2>/dev/null || echo "(Không có site nào)"
    echo
}

info_dakdo() {
    echo "📦 DAKDO Web Manager v$DAKDO_VERSION"
    echo "🌍 IP VPS: $(curl -s ifconfig.me)"
    echo "📁 Web Root: $WWW_DIR"
    echo "📧 Email SSL: $EMAIL"
    echo "📅 SSL tự động gia hạn: 03:00 hàng ngày"
}

menu_dakdo() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════╗"
    echo -e "║       DAKDO WEB MANAGER v$DAKDO_VERSION       ║"
    echo -e "╚══════════════════════════════════════╝${NC}"
    echo "1. Cài đặt DAKDO (Nginx + SSL tool)"
    echo "2. Thêm Website HTML mới"
    echo "3. Backup Website"
    echo "4. Xoá Website"
    echo "5. Kiểm tra Domain"
    echo "6. Danh sách Website đã cài"
    echo "7. Thông tin hệ thống"
    echo "8. Thoát"
    read -p "→ Chọn thao tác (1-8): " CHOICE
    case $CHOICE in
        1) install_base ;;
        2) add_website ;;
        3) backup_website ;;
        4) remove_website ;;
        5) read -p "🌐 Nhập domain để kiểm tra: " DOMAIN && check_domain "$DOMAIN" ;;
        6) list_websites ;;
        7) info_dakdo ;;
        8) exit 0 ;;
        *) echo "❗ Lựa chọn không hợp lệ" ;;
    esac
}

while true; do
    menu_dakdo
    read -p "Nhấn Enter để tiếp tục..." pause
done
