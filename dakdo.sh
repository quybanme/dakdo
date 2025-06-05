#!/bin/bash
# dakdo.sh - Script quản lý VPS dành cho website tĩnh HTML

GREEN='\033[0;32m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${GREEN}DAKDO VPS MANAGER - v1.4${NC}"
echo "=========================="
echo "1. Cập nhật hệ thống"
echo "2. Cài Nginx"
echo "3. Khởi động lại VPS"
echo "4. Tạo website (full tự động)"
echo "0. Thoát"
echo "=========================="
read -p "Chọn chức năng: " choice

case "$choice" in
  1)
    echo -e "${GREEN}Đang cập nhật hệ thống...${NC}"
    apt update && apt upgrade -y
    ;;
  2)
    echo -e "${GREEN}Đang cài đặt Nginx...${NC}"
    apt install nginx -y
    systemctl enable nginx
    systemctl start nginx
    ;;
  3)
    echo -e "${GREEN}Khởi động lại VPS...${NC}"
    reboot
    ;;
  4)
    read -p "Nhập tên domain (không có http/https): " domain
    echo "Chọn kiểu chuyển hướng:"
    echo "1. non-www → www.$domain (Khuyến nghị)"
    echo "2. www → non-www"
    echo "3. Không chuyển hướng"
    read -p "Lựa chọn (1/2/3): " redirect

    IP_VPS=$(curl -s https://api.ipify.org)
    IP_DOMAIN=$(dig +short "$domain" | tail -n1)

    if [[ "$IP_DOMAIN" != "$IP_VPS" ]]; then
      echo -e "${RED}[CẢNH BÁO] Domain $domain chưa trỏ về IP VPS ($IP_VPS)${NC}"
      read -p "Bạn vẫn muốn tiếp tục tạo website? (y/n): " continue
      [[ "$continue" != "y" ]] && exit
    fi

    webroot="/var/www/$domain"
    echo -e "${GREEN}Đang tạo thư mục website...${NC}"
    mkdir -p "$webroot"
    chown -R www-data:www-data "$webroot"

    echo "<!DOCTYPE html><html><head><title>$domain</title></head><body><h1>Website $domain đã hoạt động!</h1></body></html>" > "$webroot/index.html"

    echo -e "${GREEN}Đang tạo file cấu hình Nginx...${NC}"
    config_path="/etc/nginx/sites-available/$domain"

    if [[ "$redirect" == "1" ]]; then
      cat > "$config_path" <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 http://www.$domain\$request_uri;
}
server {
    listen 80;
    server_name www.$domain;
    root $webroot;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    elif [[ "$redirect" == "2" ]]; then
      cat > "$config_path" <<EOF
server {
    listen 80;
    server_name www.$domain;
    return 301 http://$domain\$request_uri;
}
server {
    listen 80;
    server_name $domain;
    root $webroot;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    else
      cat > "$config_path" <<EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $webroot;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    fi

    ln -s "$config_path" "/etc/nginx/sites-enabled/" 2>/dev/null
    nginx -t && systemctl reload nginx

    echo -e "${GREEN}Đang cài đặt SSL cho $domain...${NC}"
    apt install certbot python3-certbot-nginx -y
    certbot --nginx -d "$domain" -d "www.$domain"

    echo -e "${GREEN}✅ Website đã được tạo thành công tại https://$domain${NC}"
    ;;
  0)
    echo "Tạm biệt!"
    ;;
  *)
    echo "Lựa chọn không hợp lệ!"
    ;;
esac
