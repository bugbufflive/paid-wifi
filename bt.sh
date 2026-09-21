#!/bin/bash
#
# 付费WiFi系统 - 宝塔面板专用一键部署
# 仓库：https://github.com/bugbufflive/paid-wifi
#

set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ============ 配置（改成你的仓库） ============
REPO_URL="https://github.com/bugbufflive/paid-wifi.git"
REPO_BRANCH="main"
INSTALL_DIR="/www/wwwroot/paid-wifi"
PORT=3000

# 域名/邮箱/密码（可通过参数覆盖）
DOMAIN=""
EMAIL=""
ADMIN_PASS=""
NON_INTERACTIVE=0

# ============ 参数解析 ============
while [ $# -gt 0 ]; do
    case "$1" in
        --domain)      DOMAIN="$2"; shift 2 ;;
        --email)       EMAIL="$2"; shift 2 ;;
        --admin-pass)  ADMIN_PASS="$2"; shift 2 ;;
        --dir)         INSTALL_DIR="$2"; shift 2 ;;
        --port)        PORT="$2"; shift 2 ;;
        --yes|-y)      NON_INTERACTIVE=1; shift ;;
        --help|-h)
            cat <<EOF
用法：bash bt.sh [选项]

选项：
  --domain <域名>      后端域名
  --email <邮箱>       Let's Encrypt 邮箱
  --admin-pass <密码>  管理员密码（默认随机）
  --dir <目录>         安装目录（默认 /www/wwwroot/paid-wifi）
  --port <端口>        后端端口（默认 3000）
  --yes, -y            非交互
EOF
            exit 0
            ;;
        *) err "未知参数：$1"; exit 1 ;;
    esac
done

# ============ 检查 root ============
[ "$(id -u)" = "0" ] || { err "请用 sudo 或 root 运行"; exit 1; }

# ============ 检查宝塔环境 ============
check_bt() {
    step "检查宝塔环境"
    [ -d /www/server ] || { err "未检测到宝塔面板，请先安装宝塔"; exit 1; }
    [ -d /www/server/nginx ] || { err "宝塔未安装 Nginx，请在软件商店安装"; exit 1; }
    log "宝塔环境正常"
}

# ============ 检查 Node ============
check_node() {
    step "检查 Node.js"

    if command -v node >/dev/null 2>&1; then
        NODE_MAJOR=$(node -v | sed 's/v//' | cut -d'.' -f1)
        if [ "$NODE_MAJOR" -ge 18 ]; then
            log "Node.js $(node -v)"
            return 0
        fi
    fi

    err "未找到 Node.js 18+"
    echo ""
    echo "请在宝塔面板安装："
    echo "  软件商店 → 运行环境 → Node.js版本管理器 → 安装 20.x"
    echo ""
    echo "或命令行安装："
    echo "  curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -"
    echo "  dnf install -y nodejs   # AlmaLinux/CentOS"
    echo "  apt install -y nodejs   # Ubuntu/Debian"
    echo ""
    exit 1
}

# ============ 交互式询问 ============
ask_inputs() {
    [ "$NON_INTERACTIVE" = "1" ] && return

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   付费WiFi系统 - 宝塔一键部署          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    if [ -z "$DOMAIN" ]; then
        read -rp "后端域名（如 paid-wifi.diego.de5.net）：" DOMAIN
    fi

    if [ -n "$DOMAIN" ] && [ -z "$EMAIL" ]; then
        read -rp "Let's Encrypt 邮箱：" EMAIL
    fi

    if [ -z "$ADMIN_PASS" ]; then
        read -rsp "管理员密码（留空自动生成）：" ADMIN_PASS
        echo ""
    fi

    echo ""
    log "配置确认："
    echo "  安装目录：$INSTALL_DIR"
    echo "  后端端口：$PORT"
    echo "  后端域名：${DOMAIN:-（未设置）}"
    echo "  通知邮箱：${EMAIL:-（未设置）}"
    echo "  管理员密码：$( [ -z "$ADMIN_PASS" ] && echo '（自动生成）' || echo '（已设置）' )"
    echo ""
    read -rp "确认开始部署？[Y/n] " confirm
    case "$confirm" in
        [nN]*) err "用户取消"; exit 0 ;;
    esac
}

# ============ 获取代码 ============
fetch_code() {
    step "获取代码"

    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        if [ -d .git ]; then
            info "拉取最新代码..."
            git fetch --all --quiet
            git reset --hard "origin/${REPO_BRANCH}" --quiet
        else
            warn "$INSTALL_DIR 存在但不是 git 仓库"
        fi
    else
        mkdir -p "$(dirname $INSTALL_DIR)"
        git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
    fi

    cd "$INSTALL_DIR"
    log "代码位置：$INSTALL_DIR"
    log "当前版本：$(git rev-parse --short HEAD)"
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
        [ -z "$ADMIN_PASS" ] && ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)

        sed -i "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
        sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env
        sed -i "s|PORT=.*|PORT=${PORT}|" .env

        chmod 600 .env
        log ".env 已生成"
    else
        warn ".env 已存在"
        ADMIN_PASS=$(grep ADMIN_PASSWORD .env | cut -d= -f2)
    fi

    mkdir -p data

    # 初始化数据库
    log "初始化数据库..."
    timeout 8 node src/app.js > /tmp/paid-wifi-init.log 2>&1 || true
    ROUTER_TOKEN=$(grep "默认路由器 Token" /tmp/paid-wifi-init.log | awk '{print $NF}' | head -1)

    log "数据库已初始化"
}

# ============ 配置 systemd ============
setup_systemd() {
    step "配置 systemd 守护"

    NODE_BIN=$(command -v node)

    cat > /etc/systemd/system/paid-wifi.service <<EOF
[Unit]
Description=Paid WiFi Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}/server
ExecStart=${NODE_BIN} src/app.js
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
        err "服务启动失败，日志："
        journalctl -u paid-wifi -n 30 --no-pager
        exit 1
    fi

    # 验证
    sleep 1
    if curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
        log "健康检查通过"
    else
        err "健康检查失败"
        exit 1
    fi
}

# ============ 输出宝塔配置指引 ============
show_guide() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✅  后端部署完成                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}【后端信息】${NC}"
    echo "  安装目录：$INSTALL_DIR"
    echo "  运行端口：$PORT"
    echo "  本地健康检查：http://127.0.0.1:$PORT/health"
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
    echo "  宝塔 → 网站 → 添加站点"
    echo "    域名：${DOMAIN:-你的域名}"
    echo "    PHP版本：纯静态"
    echo "    其他留空"
    echo ""
    echo -e "${CYAN}【第 2 步】配置反向代理${NC}"
    echo "  点击站点 → 反向代理 → 添加"
    echo "    代理名称：paid-wifi-api"
    echo "    目标URL：http://127.0.0.1:$PORT"
    echo "    发送域名：\$host"
    echo ""
    echo -e "${CYAN}【第 3 步】申请 SSL${NC}"
    echo "  点击站点 → SSL → Let's Encrypt"
    echo "    勾选域名 → 申请"
    echo "    开启强制HTTPS"
    echo ""
    echo -e "${CYAN}【验证】${NC}"
    echo "  curl https://${DOMAIN:-你的域名}/health"
    echo ""
    echo -e "${CYAN}【常用命令】${NC}"
    echo "  查看日志：journalctl -u paid-wifi -f"
    echo "  重启服务：systemctl restart paid-wifi"
    echo "  查看配置：cat $INSTALL_DIR/server/.env"
    echo ""

    # 保存部署信息
    cat > /root/paid-wifi-info.txt <<EOF
部署时间：$(date)
安装目录：$INSTALL_DIR
后端端口：$PORT
后端域名：${DOMAIN:-未设置}
管理员用户名：admin
管理员密码：$ADMIN_PASS
默认路由器 ID：router-01
默认路由器 Token：${ROUTER_TOKEN:-未获取}
EOF
    chmod 600 /root/paid-wifi-info.txt
    log "部署信息已保存到 /root/paid-wifi-info.txt"
    echo ""
}

# ============ 主流程 ============
main() {
    check_bt
    check_node
    ask_inputs
    fetch_code
    setup_backend
    setup_systemd
    show_guide
}

main "$@"
