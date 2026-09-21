#!/bin/bash
#
# 付费WiFi系统 - VPS 一键部署脚本
# 支持：Ubuntu 20.04+ / Debian 11+ / CentOS 8+
#
# 用法：
#   sudo bash install.sh
#   sudo bash install.sh --domain api.example.com --email admin@example.com --yes
#

set -e

# ============================================================
# 配置
# ============================================================
REPO_URL="${REPO_URL:-https://github.com/your-username/paid-wifi.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/paid-wifi}"
SERVICE_NAME="paid-wifi"
DOMAIN=""
EMAIL=""
ADMIN_PASS=""
NON_INTERACTIVE=0
SKIP_SSL=0

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 工具函数
# ============================================================
log()    { echo -e "${GREEN}[✓]${NC} $1"; }
info()   { echo -e "${BLUE}[i]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1" >&2; }
step()   { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

die() {
    error "$1"
    exit 1
}

# 检查 root
check_root() {
    [ "$(id -u)" = "0" ] || die "请用 sudo 或 root 运行"
}

# 检查系统
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        die "无法识别操作系统"
    fi

    case "$OS" in
        ubuntu|debian) ;;
        centos|rhel|rocky|almalinux) ;;
        *) die "不支持的系统：$OS（仅支持 Ubuntu/Debian/CentOS）" ;;
    esac

    log "系统：$OS $VER"
}

# 解析参数
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --domain)        DOMAIN="$2"; shift 2 ;;
            --email)         EMAIL="$2"; shift 2 ;;
            --admin-pass)    ADMIN_PASS="$2"; shift 2 ;;
            --dir)           INSTALL_DIR="$2"; shift 2 ;;
            --repo)          REPO_URL="$2"; shift 2 ;;
            --skip-ssl)      SKIP_SSL=1; shift ;;
            --yes|-y)        NON_INTERACTIVE=1; shift ;;
            --help|-h)
                cat <<EOF
用法：sudo bash install.sh [选项]

选项：
  --domain <域名>      后端域名，如 api.example.com
  --email <邮箱>       Let's Encrypt 通知邮箱
  --admin-pass <密码>  管理员密码（默认随机生成）
  --dir <目录>         安装目录（默认 /opt/paid-wifi）
  --repo <URL>         仓库地址
  --skip-ssl           跳过 HTTPS 证书申请
  --yes, -y            非交互式（全自动）
  --help, -h           显示帮助
EOF
                exit 0
                ;;
            *) die "未知参数：$1（用 --help 查看帮助）" ;;
        esac
    done
}

# 交互式询问
ask_inputs() {
    [ "$NON_INTERACTIVE" = "1" ] && return

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   付费WiFi系统 - VPS 一键部署          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    if [ -z "$DOMAIN" ]; then
        read -rp "后端域名（如 api.example.com，留空跳过 HTTPS）：" DOMAIN
    fi

    if [ -n "$DOMAIN" ] && [ -z "$EMAIL" ] && [ "$SKIP_SSL" != "1" ]; then
        read -rp "Let's Encrypt 邮箱（用于证书通知）：" EMAIL
    fi

    if [ -z "$ADMIN_PASS" ]; then
        read -rsp "管理员密码（留空自动生成）：" ADMIN_PASS
        echo ""
    fi

    echo ""
    info "配置确认："
    echo "  安装目录：$INSTALL_DIR"
    echo "  后端域名：${DOMAIN:-（未设置，跳过 HTTPS）}"
    echo "  通知邮箱：${EMAIL:-（未设置）}"
    echo "  管理员密码：$( [ -z "$ADMIN_PASS" ] && echo '（自动生成）' || echo '（已设置）' )"
    echo ""

    read -rp "确认开始部署？[Y/n] " confirm
    case "$confirm" in
        [nN]*) die "用户取消" ;;
    esac
}

# ============================================================
# 安装依赖
# ============================================================
install_deps() {
    step "安装系统依赖"

    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -qq
        apt install -y -qq \
            curl wget git nginx sqlite3 ufw \
            ca-certificates gnupg lsb-release openssl jq
    else
        # CentOS/RHEL
        yum install -y -q epel-release || true
        yum install -y -q \
            curl wget git nginx sqlite \
            ca-certificates openssl jq
        # firewalld
        yum install -y -q firewalld 2>/dev/null || true
    fi

    # 安装 Node.js 20
    if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'.' -f1 | tr -d 'v')" -lt 18 ]; then
        info "安装 Node.js 20..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            apt install -y -qq nodejs
        else
            yum install -y -q nodejs
        fi
    fi

    log "Node.js $(node -v)"
    log "npm $(npm -v)"
}

# ============================================================
# 获取代码
# ============================================================
fetch_code() {
    step "获取项目代码"

    if [ -d "$INSTALL_DIR" ]; then
        info "目录已存在，拉取最新代码..."
        cd "$INSTALL_DIR"
        if [ -d .git ]; then
            git pull --quiet || warn "git pull 失败，使用现有代码"
        else
            warn "$INSTALL_DIR 存在但不是 git 仓库，跳过拉取"
        fi
    else
        info "克隆仓库到 $INSTALL_DIR ..."
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>&1 | grep -v "Cloning into" || true
    fi

    cd "$INSTALL_DIR"
    log "代码位置：$INSTALL_DIR"
}

# ============================================================
# 安装后端
# ============================================================
setup_backend() {
    step "配置后端服务"

    cd "$INSTALL_DIR/server"

    info "安装依赖..."
    npm install --production --silent --no-audit --no-fund

    # 生成 .env
    if [ ! -f .env ]; then
        cp .env.example .env

        JWT_SECRET=$(openssl rand -hex 32)

        if [ -z "$ADMIN_PASS" ]; then
            ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)
        fi

        sed -i "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
        sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env

        chmod 600 .env
        log ".env 已生成"
    else
        warn ".env 已存在，保留原有配置"
        ADMIN_PASS=$(grep ADMIN_PASSWORD .env | cut -d= -f2)
    fi

    mkdir -p data

    # 首次启动一次，生成数据库和默认路由器 Token
    info "初始化数据库..."
    timeout 8 node src/app.js > /tmp/paid-wifi-init.log 2>&1 || true

    ROUTER_TOKEN=$(grep "默认路由器 Token" /tmp/paid-wifi-init.log | awk '{print $NF}' | head -1)

    log "数据库已初始化"
}

# ============================================================
# 配置 systemd
# ============================================================
setup_systemd() {
    step "配置 systemd 服务"

    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Paid WiFi Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}/server
ExecStart=$(command -v node) src/app.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME} --quiet
    systemctl restart ${SERVICE_NAME}

    sleep 2

    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log "服务已启动"
    else
        error "服务启动失败，查看日志：journalctl -u ${SERVICE_NAME} -n 50"
        die "部署失败"
    fi
}

# ============================================================
# 配置 Nginx
# ============================================================
setup_nginx() {
    step "配置 Nginx"

    local server_name="${DOMAIN:-_}"

    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        local nginx_conf="/etc/nginx/sites-available/paid-wifi"
        local nginx_link="/etc/nginx/sites-enabled/paid-wifi"
    else
        local nginx_conf="/etc/nginx/conf.d/paid-wifi.conf"
        local nginx_link=""
    fi

    cat > "$nginx_conf" <<EOF
# 限流区
limit_req_zone \$binary_remote_addr zone=router_limit:10m rate=120r/m;
limit_req_zone \$binary_remote_addr zone=login_limit:10m rate=10r/m;

server {
    listen 80;
    server_name ${server_name};

    client_max_body_size 10M;

    # 健康检查
    location = /health {
        proxy_pass http://127.0.0.1:3000/health;
        access_log off;
    }

    # 管理后台登录限流
    location = /api/admin/login {
        limit_req zone=login_limit burst=5 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # 路由器接口限流
    location /api/router/ {
        limit_req zone=router_limit burst=20 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # 其他请求
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 60s;
    }
}
EOF

    if [ -n "$nginx_link" ]; then
        ln -sf "$nginx_conf" "$nginx_link"
        rm -f /etc/nginx/sites-enabled/default
    fi

    nginx -t >/dev/null 2>&1 || die "Nginx 配置有误，检查 $nginx_conf"
    systemctl reload nginx
    log "Nginx 已配置"
}

# ============================================================
# 配置 HTTPS
# ============================================================
setup_ssl() {
    [ -z "$DOMAIN" ] && { warn "未设置域名，跳过 HTTPS"; return; }
    [ "$SKIP_SSL" = "1" ] && { warn "已指定 --skip-ssl，跳过 HTTPS"; return; }

    step "申请 HTTPS 证书"

    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt install -y -qq certbot python3-certbot-nginx
    else
        yum install -y -q certbot python3-certbot-nginx || {
            warn "certbot 安装失败，跳过 HTTPS"
            return
        }
    fi

    # 检查域名是否解析到本机
    local server_ip
    server_ip=$(curl -s --max-time 5 ifconfig.me || echo "unknown")
    local domain_ip
    domain_ip=$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1 || echo "")

    if [ "$domain_ip" != "$server_ip" ]; then
        warn "域名 $DOMAIN 解析到 $domain_ip，本机 IP 是 $server_ip"
        warn "HTTPS 申请可能失败，请确认 DNS 已生效"
    fi

    local email_arg
    if [ -n "$EMAIL" ]; then
        email_arg="--email $EMAIL"
    else
        email_arg="--register-unsafely-without-email"
    fi

    certbot --nginx \
        -d "$DOMAIN" \
        $email_arg \
        --agree-tos \
        --no-eff-email \
        --redirect \
        --non-interactive 2>&1 | tail -5

    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        log "HTTPS 证书已安装"
        systemctl reload nginx
    else
        warn "HTTPS 申请失败，可稍后手动执行："
        warn "  certbot --nginx -d $DOMAIN"
    fi
}

# ============================================================
# 配置防火墙
# ============================================================
setup_firewall() {
    step "配置防火墙"

    if command -v ufw >/dev/null 2>&1; then
        ufw allow 22/tcp >/dev/null 2>&1 || true
        ufw allow 80/tcp >/dev/null 2>&1 || true
        ufw allow 443/tcp >/dev/null 2>&1 || true
        ufw --force enable >/dev/null 2>&1 || true
        log "ufw 已配置"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        systemctl enable --now firewalld >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-service=http >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-service=https >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        log "firewalld 已配置"
    else
        warn "未找到防火墙工具，跳过"
    fi
}

# ============================================================
# 设置备份定时任务
# ============================================================
setup_backup() {
    step "配置备份"

    mkdir -p /opt/backups

    cat > /etc/systemd/system/paid-wifi-backup.service <<EOF
[Unit]
Description=Paid WiFi Backup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_DIR}/deploy/scripts/backup.sh
User=root
EOF

    cat > /etc/systemd/system/paid-wifi-backup.timer <<EOF
[Unit]
Description=Run Paid WiFi backup daily

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=600

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable paid-wifi-backup.timer --quiet 2>/dev/null || warn "备份定时器启用失败（可能未配置 rclone）"

    log "备份定时任务已配置（每天 03:00）"
}

# ============================================================
# 最终验证
# ============================================================
verify() {
    step "验证部署"

    # 后端进程
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log "后端服务运行中"
    else
        error "后端服务未运行"
        return 1
    fi

    # 本地健康检查
    sleep 1
    if curl -sf http://127.0.0.1:3000/health >/dev/null 2>&1; then
        log "本地健康检查通过"
    else
        error "本地健康检查失败"
        return 1
    fi

    # Nginx
    if systemctl is-active --quiet nginx; then
        log "Nginx 运行中"
    else
        error "Nginx 未运行"
        return 1
    fi

    # 公网访问
    if [ -n "$DOMAIN" ]; then
        if curl -sf "https://$DOMAIN/health" >/dev/null 2>&1; then
            log "HTTPS 访问正常"
        elif curl -sf "http://$DOMAIN/health" >/dev/null 2>&1; then
            log "HTTP 访问正常（HTTPS 未配置）"
        else
            warn "公网访问失败，请检查 DNS 解析"
        fi
    fi

    return 0
}

# ============================================================
# 显示结果
# ============================================================
show_result() {
    local access_url
    if [ -n "$DOMAIN" ]; then
        if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
            access_url="https://$DOMAIN"
        else
            access_url="http://$DOMAIN"
        fi
    else
        local ip
        ip=$(curl -s --max-time 5 ifconfig.me || echo "服务器IP")
        access_url="http://$ip"
    fi

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║               ✅  部署完成                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}【访问地址】${NC}"
    echo "  后端 API：$access_url"
    echo "  健康检查：$access_url/health"
    echo ""
    echo -e "${CYAN}【管理员账号】${NC}"
    echo "  用户名：admin"
    echo "  密码：${ADMIN_PASS}"
    echo ""
    if [ -n "$ROUTER_TOKEN" ]; then
        echo -e "${CYAN}【默认路由器】${NC}"
        echo "  Router ID：router-01"
        echo "  Token：$ROUTER_TOKEN"
        echo ""
        echo -e "${YELLOW}  请立即把这个 Token 配置到路由器端${NC}"
        echo ""
    fi

    echo -e "${CYAN}【常用命令】${NC}"
    echo "  查看状态：systemctl status $SERVICE_NAME"
    echo "  查看日志：journalctl -u $SERVICE_NAME -f"
    echo "  重启服务：systemctl restart $SERVICE_NAME"
    echo "  查看配置：cat $INSTALL_DIR/server/.env"
    echo ""

    echo -e "${CYAN}【下一步】${NC}"
    echo "  1. 部署 Cloudflare Worker（可选）"
    echo "     cd $INSTALL_DIR/worker"
    echo "     npm install && npx wrangler deploy"
    echo ""
    echo "  2. 配置路由器"
    echo "     wget -O - https://raw.githubusercontent.com/your-username/paid-wifi/main/router/install.sh | sh"
    echo "     然后编辑 /etc/paid_wifi/config.sh"
    echo ""
    echo -e "${CYAN}【重要提示】${NC}"
    echo "  · 立即修改管理员密码：vi $INSTALL_DIR/server/.env"
    echo "  · 配置备份：rclone config（推荐 Cloudflare R2）"
    echo "  · 保护后台：配置 Cloudflare Access"
    echo ""

    # 保存部署信息
    cat > /root/paid-wifi-info.txt <<EOF
部署时间：$(date)
安装目录：$INSTALL_DIR
访问地址：$access_url
管理员用户名：admin
管理员密码：${ADMIN_PASS}
默认路由器 ID：router-01
默认路由器 Token：${ROUTER_TOKEN}
EOF
    chmod 600 /root/paid-wifi-info.txt

    log "部署信息已保存到 /root/paid-wifi-info.txt"
    echo ""
}

# ============================================================
# 主流程
# ============================================================
main() {
    check_root
    check_os
    parse_args "$@"
    ask_inputs

    install_deps
    fetch_code
    setup_backend
    setup_systemd
    setup_nginx
    setup_ssl
    setup_firewall
    setup_backup

    if verify; then
        show_result
    else
        error "部署过程中出现问题，请检查日志"
        echo ""
        echo "排查建议："
        echo "  1. 后端日志：journalctl -u paid-wifi -n 100"
        echo "  2. Nginx 日志：tail -50 /var/log/nginx/error.log"
        echo "  3. 服务状态：systemctl status paid-wifi nginx"
        exit 1
    fi
}

main "$@"