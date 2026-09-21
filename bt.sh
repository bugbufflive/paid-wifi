log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }   # ← 加这一行
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
#!/bin/bash
#
# 付费WiFi系统 - 宝塔面板一键部署（自包含版）
#

set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

INSTALL_DIR="/www/wwwroot/paid-wifi"
PORT=3000
DOMAIN=""
EMAIL=""
ADMIN_PASS=""
NON_INTERACTIVE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --domain)      DOMAIN="$2"; shift 2 ;;
        --email)       EMAIL="$2"; shift 2 ;;
        --admin-pass)  ADMIN_PASS="$2"; shift 2 ;;
        --dir)         INSTALL_DIR="$2"; shift 2 ;;
        --port)        PORT="$2"; shift 2 ;;
        --yes|-y)      NON_INTERACTIVE=1; shift ;;
        --help|-h)     echo "用法: bash bt.sh [--domain x] [--email x] [--yes]"; exit 0 ;;
        *) err "未知参数：$1"; exit 1 ;;
    esac
done

[ "$(id -u)" = "0" ] || { err "请用 root 运行"; exit 1; }

# ============ 检查宝塔 ============
step "检查宝塔环境"
[ -d /www/server ] || { err "未检测到宝塔面板"; exit 1; }
[ -d /www/server/nginx ] || { err "宝塔未安装 Nginx"; exit 1; }
log "宝塔环境正常"

# ============ 检查 Node ============
step "检查 Node.js"
if ! command -v node >/dev/null 2>&1; then
    err "未找到 node，请先执行软链："
    echo "  ln -sf /www/server/nodejs/v20.20.2/bin/node /usr/bin/node"
    echo "  ln -sf /www/server/nodejs/v20.20.2/bin/npm  /usr/bin/npm"
    echo "  ln -sf /www/server/nodejs/v20.20.2/bin/npx  /usr/bin/npx"
    exit 1
fi
NODE_MAJOR=$(node -v | sed 's/v//' | cut -d'.' -f1)
[ "$NODE_MAJOR" -ge 18 ] || { err "Node 版本过低：$(node -v)"; exit 1; }
log "Node.js $(node -v)"

# ============ 交互输入 ============
if [ "$NON_INTERACTIVE" != "1" ]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   付费WiFi系统 - 宝塔一键部署          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    [ -z "$DOMAIN" ] && read -rp "后端域名（如 paid-wifi.diego.de5.net）：" DOMAIN
    [ -n "$DOMAIN" ] && [ -z "$EMAIL" ] && read -rp "Let's Encrypt 邮箱：" EMAIL
    [ -z "$ADMIN_PASS" ] && { read -rsp "管理员密码（留空自动生成）：" ADMIN_PASS; echo ""; }
    echo ""
    echo "  安装目录：$INSTALL_DIR"
    echo "  后端端口：$PORT"
    echo "  域名：${DOMAIN:-未设置}"
    echo ""
    read -rp "确认开始部署？[Y/n] " confirm
    case "$confirm" in [nN]*) exit 0 ;; esac
fi

# ============ 创建目录 ============
step "创建项目结构"
mkdir -p "$INSTALL_DIR/server/src/middleware"
mkdir -p "$INSTALL_DIR/server/src/routes"
mkdir -p "$INSTALL_DIR/server/data"
cd "$INSTALL_DIR"
log "目录：$INSTALL_DIR"

# ============ 生成 server/package.json ============
step "生成代码文件"

cat > server/package.json <<'PKGEOF'
{
  "name": "paid-wifi-server",
  "version": "1.0.0",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "node --watch src/app.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "better-sqlite3": "^11.3.0",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.21.0",
    "express-rate-limit": "^7.4.0",
    "helmet": "^7.1.0",
    "jsonwebtoken": "^9.0.2"
  }
}
PKGEOF

cat > server/.env.example <<'ENVEOF'
PORT=3000
JWT_SECRET=change_me_to_random_32_chars_min
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
DB_PATH=./data/paid_wifi.db
EXPIRE_CHECK_INTERVAL=30
ENVEOF

cat > server/src/config.js <<'CFGEOF'
require('dotenv').config();
module.exports = {
  port: parseInt(process.env.PORT || '3000', 10),
  jwtSecret: process.env.JWT_SECRET || 'dev_secret_change_me',
  adminUsername: process.env.ADMIN_USERNAME || 'admin',
  adminPassword: process.env.ADMIN_PASSWORD || 'admin123',
  dbPath: process.env.DB_PATH || './data/paid_wifi.db',
  expireCheckInterval: parseInt(process.env.EXPIRE_CHECK_INTERVAL || '30', 10),
};
CFGEOF

cat > server/src/db.js <<'DBEOF'
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const config = require('./config');

const dbDir = path.dirname(path.resolve(config.dbPath));
if (!fs.existsSync(dbDir)) fs.mkdirSync(dbDir, { recursive: true });

const db = new Database(path.resolve(config.dbPath));
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS admins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  );
  CREATE TABLE IF NOT EXISTS packages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    price REAL NOT NULL,
    duration_minutes INTEGER NOT NULL,
    description TEXT,
    enabled INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  );
  CREATE TABLE IF NOT EXISTS routers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    router_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    location TEXT,
    status TEXT DEFAULT 'offline',
    last_heartbeat TEXT,
    version TEXT,
    allowed_count INTEGER DEFAULT 0,
    enabled INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  );
  CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY,
    package_id INTEGER NOT NULL,
    package_name TEXT NOT NULL,
    amount REAL NOT NULL,
    duration_minutes INTEGER NOT NULL,
    user_mac TEXT NOT NULL,
    user_contact TEXT,
    router_id TEXT,
    status TEXT DEFAULT 'pending',
    created_at TEXT DEFAULT (datetime('now','localtime')),
    paid_at TEXT,
    confirmed_at TEXT,
    expires_at TEXT
  );
  CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id TEXT NOT NULL,
    user_mac TEXT NOT NULL,
    package_name TEXT,
    router_id TEXT,
    started_at TEXT DEFAULT (datetime('now','localtime')),
    expires_at TEXT NOT NULL,
    active INTEGER DEFAULT 1
  );
  CREATE TABLE IF NOT EXISTS pending_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    user_mac TEXT NOT NULL,
    order_id TEXT,
    router_id TEXT,
    expires_at TEXT,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  );
  CREATE TABLE IF NOT EXISTS action_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    user_mac TEXT,
    order_id TEXT,
    router_id TEXT,
    status TEXT DEFAULT 'success',
    message TEXT,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  );
`);

if (db.prepare('SELECT COUNT(*) AS c FROM admins').get().c === 0) {
  const hash = bcrypt.hashSync(config.adminPassword, 10);
  db.prepare('INSERT INTO admins (username, password_hash) VALUES (?, ?)')
    .run(config.adminUsername, hash);
  console.log(`[init] 管理员：${config.adminUsername}`);
}

if (db.prepare('SELECT COUNT(*) AS c FROM packages').get().c === 0) {
  const stmt = db.prepare('INSERT INTO packages (name, price, duration_minutes, description, sort_order) VALUES (?, ?, ?, ?, ?)');
  stmt.run('1小时', 2, 60, '60 分钟 · 单设备', 1);
  stmt.run('1天', 5, 1440, '24 小时 · 单设备', 2);
  stmt.run('1周', 20, 10080, '7 天 · 单设备', 3);
  stmt.run('1月', 50, 43200, '30 天 · 单设备', 4);
}

if (db.prepare('SELECT COUNT(*) AS c FROM routers').get().c === 0) {
  const token = crypto.randomBytes(24).toString('hex');
  db.prepare('INSERT INTO routers (router_id, name, token, location) VALUES (?, ?, ?, ?)')
    .run('router-01', '默认路由器', token, '未设置');
  console.log(`[init] 默认路由器 Token：${token}`);
}

module.exports = db;
DBEOF

cat > server/src/middleware/auth.js <<'AUTHMIDEOF'
const jwt = require('jsonwebtoken');
const config = require('../config');
function authMiddleware(req, res, next) {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return res.status(401).json({ ok: false, error: '未登录' });
  try {
    req.admin = jwt.verify(token, config.jwtSecret);
    next();
  } catch {
    return res.status(401).json({ ok: false, error: '登录已过期' });
  }
}
module.exports = { authMiddleware };
AUTHMIDEOF

cat > server/src/middleware/routerAuth.js <<'RTAUTHMIDEOF'
const db = require('../db');
function routerAuth(req, res, next) {
  const token = req.headers['x-router-token'] || req.query.token;
  const routerId = req.query.router_id || req.body?.router_id;
  if (!token || !routerId) return res.status(401).json({ ok: false, error: '缺少认证信息' });
  const router = db.prepare('SELECT * FROM routers WHERE router_id = ? AND token = ? AND enabled = 1').get(routerId, token);
  if (!router) return res.status(401).json({ ok: false, error: '认证失败' });
  req.router = router;
  next();
}
module.exports = { routerAuth };
RTAUTHMIDEOF

cat > server/src/routes/auth.js <<'AUTHROUTEEOF'
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const config = require('../config');
const router = express.Router();

router.post('/login', (req, res) => {
  const { username, password } = req.body || {};
  const admin = db.prepare('SELECT * FROM admins WHERE username = ?').get(username);
  if (!admin || !bcrypt.compareSync(password, admin.password_hash)) {
    return res.status(401).json({ ok: false, error: '用户名或密码错误' });
  }
  const token = jwt.sign({ id: admin.id, username: admin.username }, config.jwtSecret, { expiresIn: '7d' });
  res.json({ ok: true, data: { token, username: admin.username } });
});

module.exports = router;
AUTHROUTEEOF

cat > server/src/routes/public.js <<'PUBLICEOF'
const express = require('express');
const db = require('../db');
const router = express.Router();

function genOrderId() {
  const d = new Date();
  const ds = d.getFullYear() + String(d.getMonth()+1).padStart(2,'0') + String(d.getDate()).padStart(2,'0');
  const prefix = `PW-${ds}-`;
  const row = db.prepare('SELECT id FROM orders WHERE id LIKE ? ORDER BY id DESC LIMIT 1').get(prefix + '%');
  let seq = 1;
  if (row) { const n = parseInt(row.id.split('-')[2], 10); if (!isNaN(n)) seq = n + 1; }
  return prefix + String(seq).padStart(3, '0');
}

router.get('/packages', (req, res) => {
  const list = db.prepare('SELECT id, name, price, duration_minutes, description FROM packages WHERE enabled = 1 ORDER BY sort_order ASC, price ASC').all();
  res.json({ ok: true, data: list });
});

router.post('/orders', (req, res) => {
  const { packageId, userMac, userContact, routerId } = req.body || {};
  if (!packageId || !userMac) return res.status(400).json({ ok: false, error: '缺少参数' });
  const pkg = db.prepare('SELECT * FROM packages WHERE id = ? AND enabled = 1').get(packageId);
  if (!pkg) return res.status(404).json({ ok: false, error: '套餐不存在' });
  const orderId = genOrderId();
  db.prepare('INSERT INTO orders (id, package_id, package_name, amount, duration_minutes, user_mac, user_contact, router_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
    .run(orderId, pkg.id, pkg.name, pkg.price, pkg.duration_minutes, userMac.toLowerCase(), userContact || null, routerId || 'router-01');
  res.json({ ok: true, data: { orderId, packageName: pkg.name, amount: pkg.price, durationMinutes: pkg.duration_minutes } });
});

router.get('/orders/:id', (req, res) => {
  const order = db.prepare('SELECT id, status, amount, duration_minutes, expires_at, package_name FROM orders WHERE id = ?').get(req.params.id);
  if (!order) return res.status(404).json({ ok: false, error: '订单不存在' });
  res.json({ ok: true, data: order });
});

router.post('/orders/:id/pay', (req, res) => {
  const r = db.prepare("UPDATE orders SET status='paid', paid_at=datetime('now','localtime') WHERE id = ? AND status = 'pending'").run(req.params.id);
  if (r.changes === 0) return res.status(400).json({ ok: false, error: '状态不允许' });
  res.json({ ok: true });
});

module.exports = router;
PUBLICEOF

cat > server/src/routes/admin.js <<'ADMINEOF'
const express = require('express');
const db = require('../db');
const { authMiddleware } = require('../middleware/auth');
const router = express.Router();
router.use(authMiddleware);

function fmt(d) {
  const p = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

router.get('/stats', (req, res) => {
  const rid = req.query.router_id;
  const where = rid ? ' AND router_id = ?' : '';
  const params = rid ? [rid] : [];
  const todayRevenue = db.prepare(`SELECT COALESCE(SUM(amount),0) AS total FROM orders WHERE date(paid_at)=date('now','localtime') AND status IN ('paid','confirmed','expired') ${where}`).get(...params).total;
  const todayOrders = db.prepare(`SELECT COUNT(*) AS c FROM orders WHERE date(created_at)=date('now','localtime') ${where}`).get(...params).c;
  const pendingCount = db.prepare(`SELECT COUNT(*) AS c FROM orders WHERE status='paid' ${where}`).get(...params).c;
  const onlineCount = db.prepare(`SELECT COUNT(*) AS c FROM sessions WHERE active=1 ${where}`).get(...params).c;
  res.json({ ok: true, data: { todayRevenue, todayOrders, pendingCount, onlineCount } });
});

router.get('/orders', (req, res) => {
  const { status, keyword, router_id } = req.query;
  const limit = Math.min(parseInt(req.query.limit || '100', 10), 500);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
  let sql = 'SELECT * FROM orders WHERE 1=1';
  const params = [];
  if (status && status !== 'all') { sql += ' AND status = ?'; params.push(status); }
  if (router_id) { sql += ' AND router_id = ?'; params.push(router_id); }
  if (keyword) { sql += ' AND (id LIKE ? OR user_mac LIKE ? OR user_contact LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
  sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);
  res.json({ ok: true, data: db.prepare(sql).all(...params) });
});

router.post('/orders/:id/confirm', (req, res) => {
  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  if (!order) return res.status(404).json({ ok: false, error: '订单不存在' });
  if (order.status !== 'paid') return res.status(400).json({ ok: false, error: '状态不允许' });
  const expiresAt = fmt(new Date(Date.now() + order.duration_minutes * 60000));
  db.transaction(() => {
    db.prepare("UPDATE orders SET status='confirmed', confirmed_at=datetime('now','localtime'), expires_at=? WHERE id=?").run(expiresAt, order.id);
    db.prepare('INSERT INTO sessions (order_id, user_mac, package_name, router_id, expires_at) VALUES (?, ?, ?, ?, ?)').run(order.id, order.user_mac, order.package_name, order.router_id, expiresAt);
    db.prepare("INSERT INTO pending_actions (action, user_mac, order_id, router_id, expires_at) VALUES ('allow', ?, ?, ?, ?)").run(order.user_mac, order.id, order.router_id, expiresAt);
  })();
  res.json({ ok: true, data: { orderId: order.id, expiresAt } });
});

router.post('/orders/:id/reject', (req, res) => {
  const r = db.prepare("UPDATE orders SET status='cancelled' WHERE id=? AND status='paid'").run(req.params.id);
  if (r.changes === 0) return res.status(400).json({ ok: false, error: '状态不允许' });
  res.json({ ok: true });
});

router.get('/sessions', (req, res) => {
  const active = parseInt(req.query.active ?? '1', 10);
  const rid = req.query.router_id;
  let sql = 'SELECT * FROM sessions WHERE active = ?';
  const params = [active];
  if (rid) { sql += ' AND router_id = ?'; params.push(rid); }
  sql += ' ORDER BY started_at DESC';
  res.json({ ok: true, data: db.prepare(sql).all(...params) });
});

router.post('/sessions/:mac/kick', (req, res) => {
  const mac = req.params.mac.toLowerCase();
  const s = db.prepare("SELECT * FROM sessions WHERE user_mac=? AND active=1 ORDER BY started_at DESC LIMIT 1").get(mac);
  if (!s) return res.status(404).json({ ok: false, error: '未找到会话' });
  db.transaction(() => {
    db.prepare('UPDATE sessions SET active=0 WHERE id=?').run(s.id);
    db.prepare("INSERT INTO pending_actions (action, user_mac, order_id, router_id) VALUES ('disconnect', ?, ?, ?)").run(mac, s.order_id, s.router_id);
  })();
  res.json({ ok: true });
});

router.get('/packages', (req, res) => {
  res.json({ ok: true, data: db.prepare('SELECT * FROM packages ORDER BY sort_order ASC').all() });
});

router.get('/routers', (req, res) => {
  const list = db.prepare('SELECT r.*, (SELECT COUNT(*) FROM sessions s WHERE s.router_id=r.router_id AND s.active=1) AS online_count FROM routers r ORDER BY r.created_at ASC').all();
  const now = Date.now();
  const data = list.map(r => {
    const online = r.last_heartbeat && (now - new Date(r.last_heartbeat.replace(' ', 'T')).getTime() < 90000);
    return { ...r, status: r.enabled ? (online ? 'online' : 'offline') : 'disabled' };
  });
  res.json({ ok: true, data });
});

router.get('/action-logs', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit || '100', 10), 500);
  res.json({ ok: true, data: db.prepare('SELECT * FROM action_logs ORDER BY created_at DESC LIMIT ?').all(limit) });
});

module.exports = router;
ADMINEOF

cat > server/src/routes/router.js <<'ROUTEREOF'
const express = require('express');
const db = require('../db');
const { routerAuth } = require('../middleware/routerAuth');
const router = express.Router();

router.get('/actions', routerAuth, (req, res) => {
  const routerId = req.router.router_id;
  const actions = db.transaction(() => {
    const rows = db.prepare('SELECT id, action, user_mac, order_id, expires_at FROM pending_actions WHERE router_id=? ORDER BY created_at ASC LIMIT 20').all(routerId);
    if (rows.length > 0) {
      const ids = rows.map(r => r.id);
      const ph = ids.map(() => '?').join(',');
      db.prepare(`DELETE FROM pending_actions WHERE id IN (${ph})`).run(...ids);
    }
    return rows;
  })();
  res.json({ ok: true, data: actions });
});

router.post('/heartbeat', routerAuth, (req, res) => {
  const { version, allowed_count } = req.body || {};
  db.prepare("UPDATE routers SET last_heartbeat=datetime('now','localtime'), version=COALESCE(?,version), allowed_count=COALESCE(?,allowed_count) WHERE router_id=?")
    .run(version ?? null, allowed_count ?? null, req.router.router_id);
  res.json({ ok: true });
});

router.post('/report', routerAuth, (req, res) => {
  const { action, user_mac, order_id, status, message } = req.body || {};
  db.prepare('INSERT INTO action_logs (action, user_mac, order_id, router_id, status, message) VALUES (?, ?, ?, ?, ?, ?)')
    .run(action, user_mac || null, order_id || null, req.router.router_id, status || 'success', message || null);
  res.json({ ok: true });
});

module.exports = router;
ROUTEREOF

cat > server/src/app.js <<'APPEOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const config = require('./config');
const db = require('./db');

const authRoutes = require('./routes/auth');
const publicRoutes = require('./routes/public');
const adminRoutes = require('./routes/admin');
const routerRoutes = require('./routes/router');

const app = express();
app.set('trust proxy', 1);
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(rateLimit({ windowMs: 60*1000, max: 300, standardHeaders: true, legacyHeaders: false, message: { ok: false, error: '请求过于频繁' } }));

app.use('/api', publicRoutes);
app.use('/api/admin', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/router', routerRoutes);

app.get('/health', (req, res) => res.json({ ok: true, time: new Date().toISOString() }));

setInterval(() => {
  const expired = db.prepare("SELECT id, order_id, user_mac, router_id FROM sessions WHERE active=1 AND expires_at < datetime('now','localtime')").all();
  if (expired.length === 0) return;
  db.transaction(() => {
    for (const s of expired) {
      db.prepare('UPDATE sessions SET active=0 WHERE id=?').run(s.id);
      db.prepare("UPDATE orders SET status='expired' WHERE id=? AND status='confirmed'").run(s.order_id);
      db.prepare("INSERT INTO pending_actions (action, user_mac, order_id, router_id) VALUES ('expire', ?, ?, ?)").run(s.user_mac, s.order_id, s.router_id);
    }
  })();
  console.log(`[expire] ${expired.length} 个会话已到期`);
}, config.expireCheckInterval * 1000);

app.use((req, res) => res.status(404).json({ ok: false, error: 'Not Found' }));
app.use((err, req, res, next) => { console.error(err); res.status(500).json({ ok: false, error: err.message }); });

app.listen(config.port, () => console.log(`[server] 启动于端口 ${config.port}`));
APPEOF

log "所有代码文件已生成"

# ============ 安装依赖 ============
step "安装后端依赖"
cd "$INSTALL_DIR/server"

# 配置 npm 镜像（加速）
npm config set registry https://registry.npmmirror.com 2>/dev/null || true

npm install --production --silent --no-audit --no-fund
log "依赖安装完成"

# ============ 配置 .env ============
step "生成配置"
if [ ! -f .env ]; then
    cp .env.example .env
    JWT_SECRET=$(openssl rand -hex 32)
    [ -z "$ADMIN_PASS" ] && ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
    sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env
    sed -i "s|PORT=.*|PORT=${PORT}|" .env
    chmod 600 .env
fi

mkdir -p data

# ============ 初始化数据库 ============
step "初始化数据库"
timeout 8 node src/app.js > /tmp/paid-wifi-init.log 2>&1 || true
ROUTER_TOKEN=$(grep "默认路由器 Token" /tmp/paid-wifi-init.log | awk '{print $NF}' | head -1)
[ -z "$ROUTER_TOKEN" ] && ROUTER_TOKEN=$(grep -E "Token：" /tmp/paid-wifi-init.log | awk '{print $NF}' | head -1)

log "数据库已初始化"
[ -n "$ROUTER_TOKEN" ] && log "路由器 Token：$ROUTER_TOKEN"

# ============ systemd 服务 ============
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
    log "服务已启动"
else
    err "服务启动失败"
    journalctl -u paid-wifi -n 30 --no-pager
    exit 1
fi

sleep 1
if curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    log "健康检查通过"
else
    err "健康检查失败"
    exit 1
fi

# ============ 输出结果 ============
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
echo "  宝塔 → 网站 → 添加站点"
echo "    域名：${DOMAIN:-你的域名}"
echo "    PHP版本：纯静态"
echo ""
echo -e "${CYAN}【第 2 步】配置反向代理${NC}"
echo "  点击站点 → 反向代理 → 添加"
echo "    代理名称：paid-wifi-api"
echo "    目标URL：http://127.0.0.1:$PORT"
echo "    发送域名：\$host"
echo ""
echo -e "${CYAN}【第 3 步】申请 SSL${NC}"
echo "  点击站点 → SSL → Let's Encrypt → 申请 → 开启强制HTTPS"
echo ""
echo -e "${CYAN}【验证】${NC}"
echo "  curl https://${DOMAIN:-你的域名}/health"
echo ""

cat > /root/paid-wifi-info.txt <<EOF
部署时间：$(date)
安装目录：$INSTALL_DIR
后端端口：$PORT
管理员用户名：admin
管理员密码：$ADMIN_PASS
路由器 ID：router-01
路由器 Token：${ROUTER_TOKEN:-未获取}
EOF
chmod 600 /root/paid-wifi-info.txt
log "信息已保存到 /root/paid-wifi-info.txt"
