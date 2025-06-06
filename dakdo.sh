#!/bin/bash

# DAKDO v2.0 – Web Manager for HTML + SSL + Backup + Restore
# Author: @quybanme – https://github.com/quybanme

DAKDO_VERSION="2.0"
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
    DOMAIN_IP=$(dig +short A "$DOMAIN" | head -1)
    SERVER_IP=$(curl -s https://api.ipify.org)
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
        apt install nginx certbot python3-certbot-nginx zip unzip curl dnsutils ufw -y
        systemctl enable nginx
        systemctl start nginx
    fi

    echo -e "${GREEN}📖 Cấu hình Firewall (UFW): Mở cổng 80 và 443...${NC}"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable

    if ! crontab -l 2>/dev/null | grep -q 'certbot renew'; then
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

    ln -sf "$CONFIG_FILE" "/etc/nginx/sites-enabled/$DOMAIN"
    nginx -t && systemctl reload nginx
    echo -e "${GREEN}✅ Website $DOMAIN đã được tạo!${NC}"

    read -p "🔐 Cài SSL cho $DOMAIN? (y/n): " SSL_CONFIRM
    if [[ "$SSL_CONFIRM" == "y" ]]; then
        if check_domain "$DOMAIN"; then
            certbot --nginx --redirect --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d www.$DOMAIN
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}🔒 SSL đã cài thành công cho $DOMAIN${NC}"
            else
                echo -e "${RED}❌ Cài SSL thất bại. Vui lòng kiểm tra cấu hình hoặc kết nối.${NC}"
            fi
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
    echo -e "${YELLOW}⚠️ Hãy tắt đám mây vàng (Proxy) trên Cloudflare trước khi cài/gia hạn SSL.${NC}"
    certbot --nginx --redirect --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d www.$DOMAIN
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}🔒 SSL đã cài/gia hạn thành công cho $DOMAIN${NC}"
    else
        echo -e "${RED}❌ Cài/gia hạn SSL thất bại. Vui lòng kiểm tra cấu hình hoặc kết nối.${NC}"
    fi
}

backup_website() {
    echo -e "
💾 Chọn kiểu backup:"
    echo "1. Backup 1 website cụ thể"
    echo "2. Backup tất cả website (từng file .zip riêng)"
    echo "3. Backup tất cả website (1 file .zip duy nhất: AllWebsite-yyyy-mm-dd.zip)"
    read -p "→ Nhập lựa chọn (1-3, 0 để quay lại): " BACKUP_OPTION

    BACKUP_DIR="/root/backups"
    mkdir -p "$BACKUP_DIR"

    case "$BACKUP_OPTION" in
        1)
            read -p "🌐 Nhập domain cần backup: " DOMAIN
            if [[ -z "$DOMAIN" ]]; then
                echo -e "${RED}❌ Domain không được để trống.${NC}"
                return
            fi
            ZIP_FILE="$BACKUP_DIR/${DOMAIN}_backup_$(date +%F).zip"
            (cd "$WWW_DIR" && zip -rq "$ZIP_FILE" "$DOMAIN")
            echo -e "${GREEN}✅ Backup hoàn tất tại: $(realpath "$ZIP_FILE")${NC}"
            du -h "$ZIP_FILE"
            ;;
        2)
            echo -e "${GREEN}🔁 Backup từng website thành file riêng...${NC}"
            for DIR in "$WWW_DIR"/*; do
                if [ -d "$DIR" ]; then
                    SITE_NAME=$(basename "$DIR")
                    ZIP_FILE="$BACKUP_DIR/${SITE_NAME}_backup_$(date +%F).zip"
                    (cd "$WWW_DIR" && zip -rq "$ZIP_FILE" "$SITE_NAME")
                    echo -e "✅ Đã backup $SITE_NAME → $(realpath "$ZIP_FILE")"
                fi
            done
            ;;
        3)
            ZIP_FILE="$BACKUP_DIR/AllWebsite_$(date +%F).zip"
            echo -e "${GREEN}📦 Đang nén toàn bộ website vào 1 file duy nhất...${NC}"
            (cd "$WWW_DIR" && zip -rq "$ZIP_FILE" . -i ./*/)
            echo -e "${GREEN}✅ Backup tất cả website hoàn tất: $(realpath "$ZIP_FILE")${NC}"
            du -h "$ZIP_FILE"
            ;;
        0)
            echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
            ;;
        *)
            echo -e "${RED}❌ Lựa chọn không hợp lệ.${NC}"
            ;;
    esac
}

restore_website() {
    BACKUP_DIR="/root/backups"
    echo -e "📦 Danh sách file backup có sẵn:"
    ls "$BACKUP_DIR"/*.zip 2>/dev/null || { echo "❌ Không tìm thấy file backup."; return; }

    read -p "🗂 Nhập tên file backup cần khôi phục (vd: domain_backup_2025-06-06.zip): " ZIP_FILE
    ZIP_PATH="$BACKUP_DIR/$ZIP_FILE"

    if [ ! -f "$ZIP_PATH" ]; then
        echo -e "${RED}❌ File không tồn tại: $ZIP_PATH${NC}"
        return
    fi

    DOMAIN=$(echo "$ZIP_FILE" | cut -d'_' -f1)
    RESTORE_DIR="$WWW_DIR/$DOMAIN"
    mkdir -p "$RESTORE_DIR"

    unzip -oq "$ZIP_PATH" -d "$WWW_DIR"
    echo -e "${GREEN}✅ Đã khôi phục website $DOMAIN từ $ZIP_FILE${NC}"
    nginx -t && systemctl reload nginx
}

upload_instructions() {
    echo -e "${GREEN}📤 Hướng dẫn tải file .zip lên VPS để khôi phục website:${NC}"
    echo -e "1️⃣ Trên máy tính, mở Terminal hoặc CMD (có hỗ trợ scp)"
    echo -e "2️⃣ Chạy lệnh sau để upload file .zip lên VPS:\n"
    echo -e "   ${YELLOW}scp ten_file_backup.zip root@$(curl -s https://api.ipify.org):/root/backups/${NC}\n"
    echo -e "💡 Ví dụ:"
    echo -e "   scp ~/Downloads/ten_file.zip root@$(curl -s https://api.ipify.org):/root/backups/"
    echo -e "💬 Sau khi tải lên, quay lại menu và chọn mục 'Khôi phục Website' để tiến hành."
}

remove_website() {
    read -p "⚠ Nhập domain cần xoá (nhập 0 để quay lại): " DOMAIN
    if [[ -z "$DOMAIN" || "$DOMAIN" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
    read -p "❓ Bạn có chắc muốn xoá $DOMAIN? (gõ 'yes' để xác nhận): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo -e "${YELLOW}⏪ Hủy thao tác xoá.${NC}"
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
    echo "🌍 IP VPS: $(curl -s https://api.ipify.org)"
    echo "📁 Web Root: $WWW_DIR"
    echo "📧 Email SSL: $EMAIL"
    echo "📅 SSL tự động gia hạn: 03:00 hàng ngày"
}

menu_dakdo() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════╗"
    echo -e "         DAKDO WEB MANAGER v$DAKDO_VERSION        "
    echo -e "╚══════════════════════════════════════╝${NC}"
    echo "1. Cài đặt DAKDO (Nginx + SSL + Firewall)"
    echo "2. Thêm Website HTML mới"
    echo "3. Cài / Gia hạn SSL cho Website"
    echo "4. Kiểm tra Domain"
    echo "5. Danh sách Website đã cài"
    echo "6. Backup Website"
    echo "7. Khôi phục Website từ Backup (.zip)"
    echo "8. Hướng dẫn tải file Backup lên VPS"
    echo "9. Xoá Website"
    echo "10. Thông tin hệ thống"
    echo "0. Thoát"
    read -p "→ Chọn thao tác (0-10): " CHOICE
    case $CHOICE in
        1) install_base ;;
        2) add_website ;;
        3) ssl_manual ;;
        4)
            read -p "🌐 Nhập domain để kiểm tra (nhập 0 để quay lại): " DOMAIN
            [[ "$DOMAIN" != "0" && -n "$DOMAIN" ]] && check_domain "$DOMAIN"
            ;;
        5) list_websites ;;
        6) backup_website ;;
        7) restore_website ;;
        8) upload_instructions ;;
        9) remove_website ;;
        10) info_dakdo ;;
        0) exit 0 ;;
        *) echo "❗ Lựa chọn không hợp lệ" ;;
    esac
}

while true; do
    menu_dakdo
    read -p "Nhấn Enter để tiếp tục..." pause
done
