#!/bin/bash

# DAKDO v1.8 – Web Manager for HTML + SSL + Backup + Restore (Improved)
# Author: @quybanme – https://github.com/quybanme
# Improvements: Enhanced security, error handling, and stability

DAKDO_VERSION="1.8"
WWW_DIR="/var/www"
EMAIL="i@dakdo.com"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"
LOCK_FILE="/tmp/dakdo.lock"
LOG_FILE="/var/log/dakdo.log"
BACKUP_DIR="/root/backups"

# Create necessary directories
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p "$BACKUP_DIR"

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Script cần chạy với quyền root${NC}"
        exit 1
    fi
}

# Lock mechanism to prevent concurrent execution
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        PID=$(cat "$LOCK_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${RED}❌ DAKDO đang chạy (PID: $PID)${NC}"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Release lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Trap to ensure cleanup on exit
trap release_lock EXIT

# Validate domain name
validate_domain() {
    local domain="$1"
    # Check for valid domain format
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{1,61}\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ Domain không hợp lệ: $domain${NC}"
        return 1
    fi
    # Check for dangerous characters
    if [[ "$domain" =~ [';|&#!/bin/bash

# DAKDO v1.8 – Web Manager for HTML + SSL + Backup + Restore (Improved)
# Author: @quybanme – https://github.com/quybanme
# Improvements: Enhanced security, error handling, and stability

DAKDO_VERSION="1.8"
WWW_DIR="/var/www"
EMAIL="i@dakdo.com"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"
LOCK_FILE="/tmp/dakdo.lock"
LOG_FILE="/var/log/dakdo.log"
BACKUP_DIR="/root/backups"

# Create necessary directories
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p "$BACKUP_DIR"

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Script cần chạy với quyền root${NC}"
        exit 1
    fi
}

# Lock mechanism to prevent concurrent execution
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        PID=$(cat "$LOCK_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${RED}❌ DAKDO đang chạy (PID: $PID)${NC}"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Release lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Trap to ensure cleanup on exit
trap release_lock EXIT

\'] ]]; then
        echo -e "${RED}❌ Domain chứa ký tự không an toàn${NC}"
        return 1
    fi
    return 0
}

# Sanitize domain name
sanitize_domain() {
    local domain="$1"
    # Remove any path traversal attempts
    domain=$(basename "$domain")
    # Remove dangerous characters
    domain=${domain//[^a-zA-Z0-9.-]/}
    echo "$domain"
}

# Check disk space
check_disk_space() {
    local path="$1"
    local min_space_kb="$2"
    local available=$(df "$path" | tail -1 | awk '{print $4}')
    
    if [[ $available -lt $min_space_kb ]]; then
        echo -e "${YELLOW}⚠️ Cảnh báo: Dung lượng disk thấp (${available}KB available)${NC}"
        read -p "Tiếp tục? (y/n): " confirm
        [[ "$confirm" != "y" ]] && return 1
    fi
    return 0
}

# Backup nginx config before changes
backup_nginx_config() {
    local domain="$1"
    local config_file="/etc/nginx/sites-available/$domain"
    
    if [ -f "$config_file" ]; then
        cp "$config_file" "${config_file}.backup.$(date +%s)"
        log_action "Backed up nginx config for $domain"
    fi
}

# Test nginx configuration safely
test_nginx_config() {
    if nginx -t 2>/dev/null; then
        return 0
    else
        echo -e "${RED}❌ Cấu hình Nginx không hợp lệ${NC}"
        return 1
    fi
}

# Reload nginx safely
reload_nginx() {
    if test_nginx_config; then
        systemctl reload nginx
        log_action "Nginx reloaded successfully"
        return 0
    else
        echo -e "${RED}❌ Không thể reload Nginx do lỗi cấu hình${NC}"
        return 1
    fi
}

check_domain() {
    local domain="$1"
    
    if [[ -z "$domain" || "$domain" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return 1
    fi
    
    # Validate and sanitize domain
    validate_domain "$domain" || return 1
    domain=$(sanitize_domain "$domain")
    
    # Use timeout for dig command to prevent hanging
    local domain_ip
    domain_ip=$(timeout 10 dig +short "$domain" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    
    if [[ -z "$domain_ip" ]]; then
        echo -e "${RED}❌ Không thể resolve domain $domain${NC}"
        return 1
    fi
    
    local server_ip
    server_ip=$(timeout 10 curl -s ifconfig.me)
    
    if [ "$domain_ip" = "$server_ip" ]; then
        echo -e "${GREEN}✔ Domain $domain đã trỏ đúng IP ($server_ip)${NC}"
        return 0
    else
        echo -e "${RED}✘ Domain $domain chưa trỏ về VPS (IP hiện tại: $server_ip)${NC}"
        return 1
    fi
}

install_base() {
    log_action "Starting base installation"
    
    if command -v nginx > /dev/null; then
        echo -e "${GREEN}✅ Nginx đã được cài. Bỏ qua bước cài đặt.${NC}"
    else
        echo -e "${GREEN}🔧 Cài đặt Nginx, Certbot và công cụ hỗ trợ...${NC}"
        
        # Update package list
        if ! apt update -y; then
            echo -e "${RED}❌ Không thể update package list${NC}"
            return 1
        fi
        
        # Install packages
        if ! apt install nginx certbot python3-certbot-nginx zip unzip curl dnsutils -y; then
            echo -e "${RED}❌ Cài đặt package thất bại${NC}"
            return 1
        fi
        
        systemctl enable nginx
        systemctl start nginx
        log_action "Nginx installed and started"
    fi

    # Add SSL renewal cron job if not exists
    if ! crontab -l 2>/dev/null | grep -q 'certbot renew'; then
        (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet") | crontab -
        echo "✅ Đã thêm cron tự động gia hạn SSL"
        log_action "SSL renewal cron job added"
    fi
}

add_website() {
    read -p "🌐 Nhập domain cần thêm (nhập 0 để quay lại): " domain
    
    if [[ -z "$domain" || "$domain" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
    
    # Validate and check domain
    validate_domain "$domain" || return
    check_domain "$domain" || return
    
    domain=$(sanitize_domain "$domain")
    local site_dir="$WWW_DIR/$domain"
    
    # Check if site already exists
    if [ -d "$site_dir" ]; then
        echo -e "${YELLOW}⚠️ Website $domain đã tồn tại${NC}"
        read -p "Ghi đè? (y/n): " overwrite
        [[ "$overwrite" != "y" ]] && return
    fi
    
    # Create site directory
    mkdir -p "$site_dir"
    
    # Create default index.html if not exists
    if [ ! -f "$site_dir/index.html" ]; then
        echo "<h1>DAKDO - Website $domain hoạt động!</h1>" > "$site_dir/index.html"
    fi

    echo "🔁 Chọn kiểu chuyển hướng domain:"
    echo "1. non-www → www"
    echo "2. www → non-www"
    echo "3. Không chuyển hướng"
    read -p "→ Lựa chọn (1-3): " redirect_type

    local config_file="/etc/nginx/sites-available/$domain"
    
    # Backup existing config
    backup_nginx_config "$domain"
    
    case $redirect_type in
        1)
            cat > "$config_file" <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 http://www.$domain\$request_uri;
}
server {
    listen 80;
    server_name www.$domain;
    root $site_dir;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
            ;;
        2)
            cat > "$config_file" <<EOF
server {
    listen 80;
    server_name www.$domain;
    return 301 http://$domain\$request_uri;
}
server {
    listen 80;
    server_name $domain;
    root $site_dir;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
            ;;
        *)
            cat > "$config_file" <<EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $site_dir;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
            ;;
    esac

    # Enable site
    [ -L "/etc/nginx/sites-enabled/$domain" ] || ln -s "$config_file" "/etc/nginx/sites-enabled/"
    
    # Test and reload nginx
    if reload_nginx; then
        echo -e "${GREEN}✅ Website $domain đã được tạo!${NC}"
        log_action "Website $domain created successfully"
    else
        echo -e "${RED}❌ Tạo website thất bại${NC}"
        return 1
    fi

    read -p "🔐 Cài SSL cho $domain? (y/n): " ssl_confirm
    if [[ "$ssl_confirm" == "y" ]]; then
        install_ssl "$domain"
    fi
}

install_ssl() {
    local domain="$1"
    
    echo -e "${YELLOW}⚠️ Hãy tắt đám mây vàng (Proxy) trên Cloudflare trước khi cài SSL.${NC}"
    read -p "Đã tắt Cloudflare proxy? (y/n): " cf_confirm
    
    if [[ "$cf_confirm" != "y" ]]; then
        echo -e "${YELLOW}⏪ Hủy cài đặt SSL${NC}"
        return
    fi
    
    # Install SSL certificate
    if certbot --nginx --redirect --non-interactive --agree-tos --email "$EMAIL" -d "$domain" -d "www.$domain" 2>/dev/null; then
        echo -e "${GREEN}🔒 SSL đã cài thành công cho $domain${NC}"
        log_action "SSL installed successfully for $domain"
    else
        echo -e "${RED}❌ Cài SSL thất bại. Vui lòng kiểm tra cấu hình hoặc kết nối.${NC}"
        log_action "SSL installation failed for $domain"
    fi
}

ssl_manual() {
    read -p "🔐 Nhập domain để cài/gia hạn SSL (nhập 0 để quay lại): " domain
    
    if [[ -z "$domain" || "$domain" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
    
    validate_domain "$domain" || return
    check_domain "$domain" || return
    
    domain=$(sanitize_domain "$domain")
    install_ssl "$domain"
}

backup_website() {
    read -p "💾 Nhập domain cần backup (hoặc * để backup tất cả, 0 để quay lại): " domain
    
    if [[ -z "$domain" || "$domain" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi

    # Check disk space (minimum 100MB)
    check_disk_space "$BACKUP_DIR" 100000 || return

    if [[ "$domain" == "*" ]]; then
        echo -e "${GREEN}🔁 Đang tiến hành backup tất cả website...${NC}"
        
        for dir in "$WWW_DIR"/*; do
            if [ -d "$dir" ]; then
                local site_name=$(basename "$dir")
                local temp_zip="$BACKUP_DIR/${site_name}_backup_$(date +%F_%H%M%S).zip.tmp"
                local final_zip="${temp_zip%.tmp}"
                
                # Create atomic backup
                if zip -rq "$temp_zip" "$dir"; then
                    mv "$temp_zip" "$final_zip"
                    echo -e "✅ Đã backup $site_name → $(realpath "$final_zip")"
                    log_action "Backup completed for $site_name"
                else
                    rm -f "$temp_zip"
                    echo -e "${RED}❌ Backup thất bại cho $site_name${NC}"
                fi
            fi
        done
    else
        validate_domain "$domain" || return
        domain=$(sanitize_domain "$domain")
        
        if [ ! -d "$WWW_DIR/$domain" ]; then
            echo -e "${RED}❌ Website $domain không tồn tại${NC}"
            return
        fi
        
        local temp_zip="$BACKUP_DIR/${domain}_backup_$(date +%F_%H%M%S).zip.tmp"
        local final_zip="${temp_zip%.tmp}"
        
        # Create atomic backup
        if zip -rq "$temp_zip" "$WWW_DIR/$domain"; then
            mv "$temp_zip" "$final_zip"
            echo -e "${GREEN}✅ Backup hoàn tất tại: $(realpath "$final_zip")${NC}"
            du -h "$final_zip"
            log_action "Backup completed for $domain"
        else
            rm -f "$temp_zip"
            echo -e "${RED}❌ Backup thất bại${NC}"
        fi
    fi
    
    # Clean old backups (keep last 30 days)
    find "$BACKUP_DIR" -name "*.zip" -mtime +30 -delete 2>/dev/null
}

restore_website() {
    echo -e "📦 Danh sách file backup có sẵn:"
    ls -la "$BACKUP_DIR"/*.zip 2>/dev/null || { 
        echo "❌ Không tìm thấy file backup."; 
        return; 
    }

    read -p "🗂 Nhập tên file backup cần khôi phục (vd: domain_backup_2025-06-05.zip): " zip_file
    local zip_path="$BACKUP_DIR/$zip_file"

    if [ ! -f "$zip_path" ]; then
        echo -e "${RED}❌ File không tồn tại: $zip_path${NC}"
        return
    fi

    # Extract domain name from filename
    local domain=$(echo "$zip_file" | cut -d'_' -f1)
    validate_domain "$domain" || return
    
    domain=$(sanitize_domain "$domain")
    local restore_dir="$WWW_DIR/$domain"

    # Backup existing site if it exists
    if [ -d "$restore_dir" ]; then
        echo -e "${YELLOW}⚠️ Website $domain đã tồn tại${NC}"
        read -p "Ghi đè? (y/n): " overwrite
        [[ "$overwrite" != "y" ]] && return
        
        # Create backup of existing site
        local backup_existing="$BACKUP_DIR/${domain}_before_restore_$(date +%s).zip"
        zip -rq "$backup_existing" "$restore_dir"
        echo -e "${GREEN}💾 Đã backup website hiện tại tại: $backup_existing${NC}"
    fi

    mkdir -p "$restore_dir"

    # Test zip file integrity
    if ! unzip -t "$zip_path" >/dev/null 2>&1; then
        echo -e "${RED}❌ File backup bị lỗi hoặc corrupt${NC}"
        return
    fi

    # Restore website
    if unzip -oq "$zip_path" -d "$restore_dir"; then
        echo -e "${GREEN}✅ Đã khôi phục website $domain từ $zip_file${NC}"
        log_action "Website $domain restored from $zip_file"
        reload_nginx
    else
        echo -e "${RED}❌ Khôi phục thất bại${NC}"
    fi
}

upload_instructions() {
    local server_ip
    server_ip=$(timeout 10 curl -s ifconfig.me)
    
    echo -e "${GREEN}📤 Hướng dẫn tải file .zip lên VPS để khôi phục website:${NC}"
    echo -e "1️⃣ Trên máy tính, mở Terminal hoặc CMD (có hỗ trợ scp)"
    echo -e "2️⃣ Chạy lệnh sau để upload file .zip lên VPS:\n"
    echo -e "   ${YELLOW}scp ten_file_backup.zip root@${server_ip}:${BACKUP_DIR}/${NC}\n"
    echo -e "💡 Ví dụ:"
    echo -e "   scp ~/Downloads/domain_backup.zip root@${server_ip}:${BACKUP_DIR}/"
    echo -e "💬 Sau khi tải lên, quay lại menu và chọn mục 'Khôi phục Website' để tiến hành."
}

remove_website() {
    read -p "⚠ Nhập domain cần xoá (nhập 0 để quay lại): " domain
    
    if [[ -z "$domain" || "$domain" == "0" ]]; then
        echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
        return
    fi
    
    validate_domain "$domain" || return
    domain=$(sanitize_domain "$domain")
    
    if [ ! -d "$WWW_DIR/$domain" ]; then
        echo -e "${RED}❌ Website $domain không tồn tại${NC}"
        return
    fi
    
    echo -e "${RED}⚠️ CẢNH BÁO: Thao tác này sẽ xóa hoàn toàn website $domain${NC}"
    read -p "Bạn có chắc chắn? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${YELLOW}⏪ Hủy thao tác xóa${NC}"
        return
    fi
    
    # Create final backup before deletion
    local final_backup="$BACKUP_DIR/${domain}_final_backup_$(date +%s).zip"
    zip -rq "$final_backup" "$WWW_DIR/$domain"
    echo -e "${GREEN}💾 Đã tạo backup cuối cùng: $final_backup${NC}"
    
    # Remove SSL certificate
    certbot delete --cert-name "$domain" --non-interactive 2>/dev/null
    
    # Remove files and configs
    rm -rf "$WWW_DIR/$domain"
    rm -f "/etc/nginx/sites-enabled/$domain"
    rm -f "/etc/nginx/sites-available/$domain"
    rm -f "/etc/nginx/sites-available/$domain.backup."*
    
    if reload_nginx; then
        echo -e "${RED}🗑 Website $domain đã bị xoá${NC}"
        log_action "Website $domain removed"
    else
        echo -e "${RED}❌ Xóa website nhưng reload nginx thất bại${NC}"
    fi
}

list_websites() {
    echo -e "\n🌐 Danh sách website đã cài:"
    if ls /etc/nginx/sites-available/* >/dev/null 2>&1; then
        for site in /etc/nginx/sites-available/*; do
            local site_name=$(basename "$site")
            if [[ "$site_name" != "default" ]]; then
                local ssl_status="❌"
                if [ -d "/etc/letsencrypt/live/$site_name" ]; then
                    ssl_status="✅"
                fi
                echo -e "  🌍 $site_name (SSL: $ssl_status)"
            fi
        done
    else
        echo "(Không có site nào)"
    fi
    echo
}

info_dakdo() {
    local server_ip
    server_ip=$(timeout 10 curl -s ifconfig.me || echo "N/A")
    
    echo "📦 DAKDO Web Manager v$DAKDO_VERSION"
    echo "🌍 IP VPS: $server_ip"
    echo "📁 Web Root: $WWW_DIR"
    echo "📧 Email SSL: $EMAIL"
    echo "📅 SSL tự động gia hạn: 03:00 hàng ngày"
    echo "📋 Log file: $LOG_FILE"
    echo "💾 Backup directory: $BACKUP_DIR"
    
    # Show disk usage
    echo "💽 Disk usage:"
    df -h / | tail -1 | awk '{print "  Root: " $3 "/" $2 " (" $5 " used)"}'
    df -h "$WWW_DIR" 2>/dev/null | tail -1 | awk '{print "  WWW: " $3 "/" $2 " (" $5 " used)"}'
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
    echo "9. Khôi phục Website từ Backup (.zip)"
    echo "10. Hướng dẫn tải file Backup lên VPS"
    echo "11. Thoát"
    read -p "→ Chọn thao tác (1-11): " choice
    
    case $choice in
        1) install_base ;;
        2) add_website ;;
        3) backup_website ;;
        4) remove_website ;;
        5)
            read -p "🌐 Nhập domain để kiểm tra (nhập 0 để quay lại): " domain
            if [[ -z "$domain" || "$domain" == "0" ]]; then
                echo -e "${YELLOW}⏪ Đã quay lại menu chính.${NC}"
            else
                check_domain "$domain"
            fi
            ;;
        6) list_websites ;;
        7) ssl_manual ;;
        8) info_dakdo ;;
        9) restore_website ;;
        10) upload_instructions ;;
        11) 
            echo -e "${GREEN}👋 Cảm ơn bạn đã sử dụng DAKDO!${NC}"
            log_action "DAKDO session ended"
            exit 0 
            ;;
        *) echo "❗ Lựa chọn không hợp lệ" ;;
    esac
}

# Main execution
main() {
    check_root
    acquire_lock
    
    log_action "DAKDO v$DAKDO_VERSION started"
    
    while true; do
        menu_dakdo
        read -p "Nhấn Enter để tiếp tục..." pause
    done
}

# Run main function
main "$@"
