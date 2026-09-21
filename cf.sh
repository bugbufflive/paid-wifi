#!/bin/bash
# 付费WiFi 管理后台 - CF Workers 一键部署

set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# 配置
VPS_API=""
ADMIN_DOMAIN=""

while [ $# -gt 0 ]; do
    case "$1" in
        --api) VPS_API="$2"; shift 2 ;;
        --domain) ADMIN_DOMAIN="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 交互
[ -z "$VPS_API" ] && read -rp "后端 API 地址（如 https://api.example.com）：" VPS_API
[ -z "$ADMIN_DOMAIN" ] && read -rp "前端域名（如 admin.example.com）：" ADMIN_DOMAIN

[ -z "$VPS_API" ] && { err "API 不能为空"; exit 1; }

step "检查环境"
command -v node >/dev/null || { err "需要 Node.js"; exit 1; }
command -v npm >/dev/null || { err "需要 npm"; exit 1; }
log "Node.js $(node -v)"

step "写入配置"
cat > .env.production << EOF
VITE_API_BASE_URL=/api
EOF
log ".env.production 已生成"

# 生成 worker.js（动态替换 VPS_ORIGIN）
sed "s|https://api.yourdomain.com|${VPS_API}|" worker.js > worker.js.tmp
mv worker.js.tmp worker.js
log "worker.js 已配置 VPS 地址：$VPS_API"

# 生成 wrangler.toml
cat > wrangler.toml << EOF
name = "paid-wifi-admin"
main = "worker.js"
compatibility_date = "2026-09-21"

[assets]
directory = "./dist"
binding = "ASSETS"
not_found_handling = "single-page-application"

routes = [
  { pattern = "${ADMIN_DOMAIN}", custom_domain = true }
]

[vars]
VPS_ORIGIN = "${VPS_API}"
EOF
log "wrangler.toml 已生成"

step "安装依赖"
npm config set registry https://registry.npmmirror.com 2>/dev/null || true
npm install --no-audit --no-fund

step "构建前端"
npm run build

[ -f dist/index.html ] || { err "构建失败"; exit 1; }
log "构建完成"

step "部署到 Cloudflare"
if ! command -v wrangler >/dev/null 2>&1; then
    npm install -g wrangler
fi

wrangler whoami >/dev/null 2>&1 || wrangler login

wrangler deploy

echo ""
log "✅ 部署完成"
echo ""
echo "访问 https://${ADMIN_DOMAIN}"
echo ""
