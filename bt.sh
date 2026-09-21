#!/bin/bash
#
# 付费WiFi系统 - 宝塔面板版一键部署
# 适用于：已安装宝塔面板的 CentOS/AlmaLinux/Ubuntu/Debian
#

set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

INSTALL_DIR="/www/wwwroot/paid-wifi"
REPO_URL="${REPO_URL:-https://github.com/bugbufflive/paid-wifi.git}"
PORT=3000

# ============ 检查宝塔 ============
check_bt() {
    step "检查宝塔环境"
    [ -d /www/server ] || { err "未检测到宝塔面板，请先安装宝塔"; exit 1; }
    [ -d /www/server/nginx ] || { err "宝塔未安装 Nginx，请在软件商店安装"; exit 1; }
    log "宝塔环境正常"
    log "Nginx 路径：/www/server/nginx"
}

# ============ 检查 Node ============
check_node() {
    step "检查 Node.js"
    
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node -v | sed 's/v//' | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            log "Node.js $(node -v)"
            return 0
        fi
    fi

    warn "未找到 Node.js 18+，请用宝塔安装："
    echo ""
    echo "  1. 打开宝塔 → 软件商店 → 运行环境"
    echo "  2. 安装 Node.js 版本管理器"
    echo "  3. 安装 Node.js 20 LTS"
    echo "  4. 安装完成后重新运行此脚本"
    echo ""
    exit 1
}

# ============ 克隆代码 ============
fetch_code() {
    step "获取代码"
    
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        if [ -d .git ]; then
            git pull --quiet || warn "git pull 失败"
        fi
    else
        mkdir -p "$(dirname $INSTALL_DIR)"
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
    log "代码位置：$INSTALL_DIR"
}

# ============ 部署后端 ============
setup_backend() {
    step "配置后端"
    
    cd "$INSTALL_DIR/server"
    
    log "安装依赖..."
    npm install --production --silent --no-audit --no-fund
    
    if [ ! -f .env ]; then
        cp .env.example .env
        
        JWT_SECRET=$(openssl rand -hex 32)
        ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)
        
        sed -i "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
        sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env
        sed -i "s|PORT=.*|PORT=${PORT}|" .env
        
        chmod 600 .env
        log ".env 已生成"
    else
        ADMIN_PASS=$(grep ADMIN_PASSWORD .env | cut -d= -f2)
        warn ".env 已存在"
    fi
    
    mkdir -p data
    
    # 初始化数据库
    log "初始化数据库..."
    timeout 8 node src/app.js > /tmp/paid-wifi-init.log 2>&1 || true
    
    ROUTER_TOKEN=$(grep "默认路由器 Token" /tmp/paid-wifi-init.log | awk '{print $NF}' | head -1)
    
    log "数据库已初始化"
}

# ============ 用宝塔守护进程启动 ============
setup_bt_daemon() {
    step "配置宝塔守护进程"
    
    # 宝塔的 Node 守护进程配置在 /www/server/panel/plugin/nodejs/ 下
    # 但也可以用 systemd，宝塔不冲突
    
    cat > /etc/systemd/system/paid-wifi.service <<EOF
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
    systemctl enable paid-wifi --quiet
    systemctl restart paid-wifi
    
    sleep 2
    
    if systemctl is-active --quiet paid-wifi; then
        log "后端服务已启动（端口 $PORT）"
    else
        err "服务启动失败"
        journalctl -u paid-wifi -n 20 --no-pager
        exit 1
    fi
}

# ============ 输出宝塔配置指引 ============
show_bt_guide() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✅  后端部署完成                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}【后端信息】${NC}"
    echo "  安装目录：$INSTALL_DIR"
    echo "  运行端口：$PORT"
    echo "  健康检查：http://127.0.0.1:$PORT/health"
    echo ""
    echo -e "${CYAN}【管理员账号】${NC}"
    echo "  用户名：admin"
    echo "  密码：$ADMIN_PASS"
    echo ""
    if [ -n "$ROUTER_TOKEN" ]; then
        echo -e "${CYAN}【默认路由器】${NC}"
        echo "  Router ID：router-01"
        echo "  Token：$ROUTER_TOKEN"
        echo ""
    fi
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  接下来在宝塔面板完成 3 步配置                       ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}【第 1 步】添加网站${NC}"
    echo "  宝塔面板 → 网站 → 添加站点"
    echo "    域名：paid-wifi.diego.de5.net"
    echo "    根目录：/www/wwwroot/paid-wifi/server/public（可留空）"
    echo "    PHP版本：纯静态"
    echo ""
    echo -e "${CYAN}【第 2 步】配置反向代理${NC}"
    echo "  点击刚创建的站点 → 反向代理 → 添加反向代理"
    echo "    代理名称：paid-wifi-api"
    echo "    目标URL：http://127.0.0.1:$PORT"
    echo "    发送域名：\$host"
    echo ""
    echo -e "${CYAN}【第 3 步】申请 SSL 证书${NC}"
    echo "  点击站点 → SSL → Let's Encrypt"
    echo "    勾选域名：paid-wifi.diego.de5.net"
    echo "    点击申请"
    echo "    申请成功后开启「强制HTTPS」"
    echo ""
    echo -e "${CYAN}【验证部署】${NC}"
    echo "  浏览器访问：https://paid-wifi.diego.de5.net/health"
    echo "  应返回：{\"ok\":true,\"time\":\"...\"}"
    echo ""
    echo -e "${CYAN}【查看后端日志】${NC}"
    echo "  journalctl -u paid-wifi -f"
    echo ""
    echo -e "${CYAN}【重启后端】${NC}"
    echo "  systemctl restart paid-wifi"
    echo ""
    
    # 保存信息
    cat > /root/paid-wifi-info.txt <<EOF
部署时间：$(date)
安装目录：$INSTALL_DIR
后端端口：$PORT
管理员用户名：admin
管理员密码：$ADMIN_PASS
默认路由器 ID：router-01
默认路由器 Token：$ROUTER_TOKEN
EOF
    chmod 600 /root/paid-wifi-info.txt
    log "部署信息已保存到 /root/paid-wifi-info.txt"
}

# ============ 主流程 ============
main() {
    [ "$(id -u)" = "0" ] || { err "请用 root 运行"; exit 1; }
    
    check_bt
    check_node
    fetch_code
    setup_backend
    setup_bt_daemon
    show_bt_guide
}

main "$@"
