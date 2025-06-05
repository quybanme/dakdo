#!/bin/bash

# DAKDO v1.5 – Web Manager for HTML + SSL (Gọn gàng, loại bỏ mục redirect riêng)
# Author: @quybanme – https://github.com/quybanme

DAKDO_VERSION="1.5"
WWW_DIR="/var/www"
EMAIL="i@dakdo.com"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

check_domain() {
    DOMAIN="$1"
    if [[ -z "$DOMAIN" || "$DOMAIN" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return 1
    fi
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

    if ! crontab -l | grep -q 'certbot renew'; then
        (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet") | crontab -
        echo "✅ Đã thêm cron tự động gia hạn SSL"
    fi
}

add_website() {
    read -p "🌐 Nhập domain cần thêm (nhập 0 để quay lại): " DOMAIN
    if [[ -z "$DOMAIN" || "$DOMAIN" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
    check_domain "$DOMAIN" || return
    SITE_DIR="$WWW_DIR/$DOMAIN"
    mkdir -p "$SITE_DIR"
    if [ ! -f "$SITE_DIR/index.html" ]; then
        echo "<h1>DAKDO - Website $DOMAIN hoạt động!</h1>" > "$SITE_DIR/index.html"
    fi

    echo "🔁 Chọn kiểu chuyển hướng domain:"
    echo "1. non-www → www"
    echo "2. www → non-www"
    echo "3. Không chuyển hướng"
    read -p "→ Lựa chọn (1-3): " REDIRECT_TYPE

    CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
    case $REDIRECT_TYPE in
        1)
            cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 http://www.$DOMAIN\$request_uri;
}
server {
    listen 80;
    server_name www.$DOMAIN;
    root $SITE_DIR;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
            ;;
        2)
            cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    server_name www.$DOMAIN;
    return 301 http://$DOMAIN\$request_uri;
}
server {
    listen 80;
    server_name $DOMAIN;
    root $SITE_DIR;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
            ;;
        *)
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
            ;;
    esac

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

ssl_manual() {
    read -p "🔐 Nhập domain để cài/gia hạn SSL (nhập 0 để quay lại): " DOMAIN
    if [[ -z "$DOMAIN" || "$DOMAIN" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
    check_domain "$DOMAIN" || return
    echo -e "${YELLOW}⚠️ Lưu ý: Hãy tắt đám mây vàng (Proxy) trên Cloudflare trước khi cài/gia hạn SSL.${NC}"
    certbot --nginx --redirect --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d www.$DOMAIN
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}🔒 SSL đã cài/gia hạn thành công cho $DOMAIN${NC}"
    else
        echo -e "${RED}❌ Cài/gia hạn SSL thất bại. Vui lòng kiểm tra cấu hình hoặc kết nối.${NC}"
    fi
}

backup_website() {
    read -p "💾 Nhập domain cần backup (nhập 0 để quay lại): " DOMAIN
    if [[ -z "$DOMAIN" || "$DOMAIN" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
    BACKUP_DIR="/root/backups"
    mkdir -p "$BACKUP_DIR"
    ZIP_FILE="$BACKUP_DIR/${DOMAIN}_backup_$(date +%F).zip"
    zip -r "$ZIP_FILE" "$WWW_DIR/$DOMAIN"
    echo -e "${GREEN}✅ Backup hoàn tất tại: $(realpath "$ZIP_FILE")${NC}"
    du -h "$ZIP_FILE"
}

remove_website() {
    read -p "⚠ Nhập domain cần xoá (nhập 0 để quay lại): " DOMAIN
    if [[ -z "$DOMAIN" || "$DOMAIN" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
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
    echo "7. Cài / Gia hạn SSL cho Website"
    echo "8. Thông tin hệ thống"
    echo "9. Thoát"
    echo "10. Backup toàn bộ website tĩnh"
    echo "11. Khôi phục website từ file backup"
    read -p "→ Chọn thao tác (1-9): " CHOICE
    case $CHOICE in
        10) backup_all_static_sites ;;
        11) restore_static_site ;;
        1) install_base ;;
        2) add_website ;;
        3) backup_website ;;
        4) remove_website ;;
        5)
            read -p "🌐 Nhập domain để kiểm tra (nhập 0 để quay lại): " DOMAIN
            if [[ -z "$DOMAIN" || "$DOMAIN" == "0" ]]; then
                echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
            else
                check_domain "$DOMAIN"
            fi
            ;;
        6) list_websites ;;
        7) ssl_manual ;;
        8) info_dakdo ;;
        9) exit 0 ;;
        *) echo "❗ Lựa chọn không hợp lệ" ;;
    esac
}


backup_all_static_sites() {
    BACKUP_DIR="/root/backups"
    mkdir -p "$BACKUP_DIR"
    TODAY=$(date +%F)
    echo "🗃 Bắt đầu backup toàn bộ website tĩnh HTML..."

    for SITE in /var/www/*; do
        [ -d "$SITE" ] || continue
        DOMAIN=$(basename "$SITE")
        ZIP_FILE="$BACKUP_DIR/${DOMAIN}_$TODAY.zip"
        zip -rq "$ZIP_FILE" "$SITE"
        echo "✅ Đã backup: $DOMAIN → $ZIP_FILE"
    done
}


restore_static_site() {
    echo "📂 Danh sách file backup:"
    ls /root/backups/*.zip 2>/dev/null || { echo "⚠ Không tìm thấy file backup."; read; return; }

    read -p "Nhập tên file .zip cần khôi phục (không có path): " ZIP_FILE
    FULL_PATH="/root/backups/$ZIP_FILE"

    if [[ ! -f "$FULL_PATH" ]]; then
        echo "❌ File không tồn tại: $ZIP_FILE"
        return
    fi

    TMP_DIR="/tmp/restore_$(date +%s)"
    mkdir -p "$TMP_DIR"
    unzip -q "$FULL_PATH" -d "$TMP_DIR"

    # Tìm thư mục con đầu tiên trong file zip (nếu có)
    FIRST_SUBDIR=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [[ -z "$FIRST_SUBDIR" ]]; then
        echo "❌ Không tìm thấy thư mục website trong file zip."
        rm -rf "$TMP_DIR"
        return
    fi

    DOMAIN=$(basename "$FIRST_SUBDIR")
    TARGET_DIR="/var/www/$DOMAIN"

    echo "🔁 Đang khôi phục vào: $TARGET_DIR"
    rm -rf "$TARGET_DIR"
    mv "$FIRST_SUBDIR" "$TARGET_DIR"
    chown -R www-data:www-data "$TARGET_DIR"
    rm -rf "$TMP_DIR"

    echo "✅ Đã khôi phục website tĩnh: $DOMAIN"
}

    read -p "Nhập tên file .zip cần khôi phục (không có path): " ZIP_FILE
    FULL_PATH="/root/backups/$ZIP_FILE"

    if [[ ! -f "$FULL_PATH" ]]; then
        echo "❌ File không tồn tại: $ZIP_FILE"
        return
    fi

    DOMAIN=$(echo "$ZIP_FILE" | cut -d'_' -f1)
    TARGET_DIR="/var/www/$DOMAIN"

    echo "🔁 Đang giải nén và khôi phục về: $TARGET_DIR"
    rm -rf "$TARGET_DIR"
    unzip -q "$FULL_PATH" -d /var/www/
    chown -R www-data:www-data "$TARGET_DIR"

    echo "✅ Đã khôi phục website tĩnh: $DOMAIN"
}


while true; do
    menu_dakdo
    read -p "Nhấn Enter để tiếp tục..." pause
done
