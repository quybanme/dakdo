#!/bin/bash
# dakdo.sh - Script quản lý VPS dành cho website tĩnh HTML

GREEN='\033[0;32m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${GREEN}DAKDO VPS MANAGER - v1.3${NC}"
echo "=========================="
echo "1. Cập nhật hệ thống"
echo "2. Cài Nginx"
echo "3. Khởi động lại VPS"
echo "4. Tạo website tĩnh mới"
echo "5. Cài SSL Let’s Encrypt cho website"
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
    cat > "/etc/nginx/sites-available/$domain" <<EOF
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

    ln -s "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/"
    nginx -t && systemctl reload nginx

    echo -e "${GREEN}Tạo website thành công: http://$domain${NC}"
    ;;
  5)
    read -p "Nhập tên domain cần cài SSL (không có http/https): " domain
    IP_VPS=$(curl -s https://api.ipify.org)
    IP_DOMAIN=$(dig +short "$domain" | tail -n1)

    if [[ "$IP_DOMAIN" != "$IP_VPS" ]]; then
      echo -e "${RED}[CẢNH BÁO] Domain $domain chưa trỏ về IP VPS ($IP_VPS)${NC}"
      read -p "Bạn vẫn muốn tiếp tục cài SSL? (y/n): " continue
      [[ "$continue" != "y" ]] && exit
    fi

    echo -e "${GREEN}Đang cài đặt Certbot và plugin Nginx...${NC}"
    apt install certbot python3-certbot-nginx -y

    echo -e "${GREEN}Đang cấp chứng chỉ SSL cho $domain...${NC}"
    certbot --nginx -d "$domain" -d "www.$domain"

    echo -e "${GREEN}Đã cài SSL thành công!${NC}"
    ;;
  0)
    echo "Tạm biệt!"
    ;;
  *)
    echo "Lựa chọn không hợp lệ!"
    ;;
esac
