#!/bin/bash
# DAKDO v1.5 – Tổng hợp đầy đủ chức năng quản lý website HTML tĩnh
# Author: @quybanme

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"

WWW_DIR="/var/www"
BACKUP_DIR="/root/backups"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
mkdir -p "$NGINX_AVAILABLE" "$NGINX_ENABLED" "$BACKUP_DIR"

# === Chức năng 1: Cài đặt hệ thống ===
install_base() {
  echo -e "${YELLOW}🔧 Đang cài đặt hệ thống...${NC}"
  apt update -y
  apt install nginx certbot python3-certbot-nginx curl zip unzip dnsutils -y
  systemctl enable nginx
  systemctl start nginx
  if ! crontab -l | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet") | crontab -
    echo -e "${GREEN}✅ Đã thêm cron tự động gia hạn SSL.${NC}"
  fi
}

# === Chức năng 2: Thêm website HTML ===
add_website() {
  read -p "🌐 Nhập domain cần thêm (vd: abc.com): " DOMAIN
  [[ -z "$DOMAIN" ]] && echo -e "${RED}❌ Domain không được để trống.${NC}" && return
  SITE_DIR="$WWW_DIR/$DOMAIN"
  mkdir -p "$SITE_DIR"
  [[ ! -f "$SITE_DIR/index.html" ]] && echo "<h1>DAKDO - Website $DOMAIN hoạt động!</h1>" > "$SITE_DIR/index.html"

  echo -e "${YELLOW}🔁 Chọn kiểu chuyển hướng domain:${NC}"
  echo "1. non-www → www"
  echo "2. www → non-www"
  echo "3. Không chuyển hướng"
  read -p "→ Lựa chọn (1-3): " REDIRECT_TYPE

  CONFIG_FILE="$NGINX_AVAILABLE/$DOMAIN"
  case $REDIRECT_TYPE in
    1)
      cat > "$CONFIG_FILE" <<EOF
server {{
    listen 80;
    server_name $DOMAIN;
    return 301 http://www.$DOMAIN\$request_uri;
}}
server {{
    listen 80;
    server_name www.$DOMAIN;
    root $SITE_DIR;
    index index.html;
    location / {{
        try_files \$uri \$uri/ =404;
    }}
}}
EOF
      ;;
    2)
      cat > "$CONFIG_FILE" <<EOF
server {{
    listen 80;
    server_name www.$DOMAIN;
    return 301 http://$DOMAIN\$request_uri;
}}
server {{
    listen 80;
    server_name $DOMAIN;
    root $SITE_DIR;
    index index.html;
    location / {{
        try_files \$uri \$uri/ =404;
    }}
}}
EOF
      ;;
    3)
      cat > "$CONFIG_FILE" <<EOF
server {{
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $SITE_DIR;
    index index.html;
    location / {{
        try_files \$uri \$uri/ =404;
    }}
}}
EOF
      ;;
    *)
      echo -e "${RED}❌ Lựa chọn không hợp lệ.${NC}"
      return
      ;;
  esac

  ln -sf "$CONFIG_FILE" "$NGINX_ENABLED/$DOMAIN"
  nginx -t && systemctl reload nginx
  echo -e "${GREEN}✅ Website $DOMAIN đã được cấu hình.${NC}"
}

# === Chức năng 3: Cài SSL cho website ===
install_ssl() {
  read -p "🔐 Nhập domain cần cài SSL: " DOMAIN
  [[ -z "$DOMAIN" ]] && echo -e "${RED}❌ Domain không được để trống.${NC}" && return
  [[ ! -f "$NGINX_AVAILABLE/$DOMAIN" ]] && echo -e "${RED}❌ Domain chưa được cấu hình.${NC}" && return
  DOMAIN_IP=$(dig +short "$DOMAIN" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
  SERVER_IP=$(curl -s ifconfig.me)
  [[ "$DOMAIN_IP" != "$SERVER_IP" ]] && echo -e "${RED}❌ Domain chưa trỏ đúng IP VPS ($SERVER_IP)${NC}" && return
  certbot --nginx --redirect --non-interactive --agree-tos --email i@dakdo.com -d "$DOMAIN" -d "www.$DOMAIN"
}

# === Chức năng 4: Backup website ===
backup_website() {
  echo -e "${YELLOW}💾 Chọn chế độ backup:${NC}"
  echo "1. Backup toàn bộ website"
  echo "2. Backup 1 domain cụ thể"
  read -p "→ Lựa chọn (1-2): " MODE
  TODAY=$(date +%F)
  case $MODE in
    1)
      for SITE in "$WWW_DIR"/*; do
        [ -d "$SITE" ] || continue
        DOMAIN=$(basename "$SITE")
        zip -rq "$BACKUP_DIR/${DOMAIN}_$TODAY.zip" "$SITE"
        echo "✅ Backup: $DOMAIN"
      done
      ;;
    2)
      read -p "🌐 Nhập domain cần backup: " DOMAIN
      [[ ! -d "$WWW_DIR/$DOMAIN" ]] && echo -e "${RED}❌ Không tồn tại: /var/www/$DOMAIN${NC}" && return
      zip -rq "$BACKUP_DIR/${DOMAIN}_$TODAY.zip" "$WWW_DIR/$DOMAIN"
      echo -e "${GREEN}✅ Đã backup: $DOMAIN${NC}"
      ;;
    *) echo -e "${RED}❌ Lựa chọn không hợp lệ.${NC}" ;;
  esac
}

# === Chức năng 5: Khôi phục website ===
restore_website() {
  echo -e "${YELLOW}📦 Danh sách file backup:${NC}"
  ls "$BACKUP_DIR"/*.zip 2>/dev/null || { echo -e "${RED}❌ Không có file backup nào.${NC}"; return; }
  read -p "→ Nhập tên file .zip cần khôi phục: " ZIP_NAME
  FULL_PATH="$BACKUP_DIR/$ZIP_NAME"
  [[ ! -f "$FULL_PATH" ]] && echo -e "${RED}❌ File không tồn tại.${NC}" && return

  TMP_DIR="/tmp/restore_$(date +%s)"
  mkdir -p "$TMP_DIR"
  unzip -q "$FULL_PATH" -d "$TMP_DIR"

  SUBDIR=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  if [[ -n "$SUBDIR" ]]; then
    DOMAIN=$(basename "$SUBDIR")
    TARGET="$WWW_DIR/$DOMAIN"
    rm -rf "$TARGET"
    mv "$SUBDIR" "$TARGET"
  else
    read -p "🌐 Nhập domain để khôi phục về: " DOMAIN
    TARGET="$WWW_DIR/$DOMAIN"
    mkdir -p "$TARGET"
    cp -r "$TMP_DIR"/* "$TARGET"
  fi

  chown -R www-data:www-data "$TARGET"
  rm -rf "$TMP_DIR"
  echo -e "${GREEN}✅ Đã khôi phục website: $TARGET${NC}"
}

# === Menu CLI ===
while true; do
  clear
  echo -e "${GREEN}╔════════════════════════════════╗"
  echo -e "║       DAKDO WEB MANAGER v1.5   ║"
  echo -e "╚════════════════════════════════╝${NC}"
  echo "1. Cài đặt hệ thống (nginx + ssl tool)"
  echo "2. Thêm website HTML mới"
  echo "3. Cài SSL Let's Encrypt"
  echo "4. Backup website tĩnh"
  echo "5. Khôi phục website từ file .zip"
  echo "6. Xoá website"
  echo "7. Danh sách website"
  echo "8. Thông tin hệ thống"
  echo "0. Thoát"
  read -p "→ Chọn chức năng (0-5): " MENU
  case $MENU in
    1) install_base ;;
    2) add_website ;;
    3) install_ssl ;;
    4) backup_website ;;
    5) restore_website ;;
    6) remove_website ;;
    7) list_websites ;;
    8) system_info ;;
    0) echo "Tạm biệt!"; exit 0 ;;
    *) echo -e "${RED}❌ Lựa chọn không hợp lệ.${NC}" && read -p "Nhấn Enter để tiếp tục..." ;;
  esac
  read -p "Nhấn Enter để quay lại menu chính..." tmp
done

# === Chức năng 6: Xoá website ===
remove_website() {
  read -p "🗑 Nhập domain cần xoá: " DOMAIN
  [[ -z "$DOMAIN" ]] && echo -e "${RED}❌ Domain không được để trống.${NC}" && return

  rm -rf "$WWW_DIR/$DOMAIN"
  rm -f "$NGINX_ENABLED/$DOMAIN"
  rm -f "$NGINX_AVAILABLE/$DOMAIN"

  nginx -t && systemctl reload nginx
  echo -e "${RED}🗑 Đã xoá website: $DOMAIN${NC}"
}

# === Chức năng 7: Danh sách website ===
list_websites() {
  echo -e "${YELLOW}📄 Danh sách website đã cấu hình:${NC}"
  ls $NGINX_AVAILABLE 2>/dev/null || echo "(Chưa có website nào)"
}

# === Chức năng 8: Thông tin hệ thống ===
system_info() {
  echo -e "${YELLOW}📊 Thông tin VPS:${NC}"
  echo "🌍 IP VPS: $(curl -s ifconfig.me)"
  echo "📁 Thư mục web: $WWW_DIR"
  echo "📁 Thư mục backup: $BACKUP_DIR"
  echo "📅 SSL sẽ tự động gia hạn lúc 03:00 sáng mỗi ngày (cron)"
}
