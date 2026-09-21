#!/bin/bash
# 卸载付费WiFi系统

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

[ "$(id -u)" = "0" ] || { echo -e "${RED}请用 sudo 运行${NC}"; exit 1; }

echo -e "${YELLOW}即将卸载付费WiFi系统${NC}"
echo ""
echo "将执行："
echo "  · 停止服务 paid-wifi"
echo "  · 删除 systemd 服务"
echo "  · 删除 Nginx 配置"
echo "  · 删除 /opt/paid-wifi"
echo "  · 删除备份定时器"
echo ""
echo "注意：不会删除数据库备份、SSL 证书"
echo ""
read -rp "确认卸载？输入 yes 继续：" confirm

[ "$confirm" != "yes" ] && { echo "已取消"; exit 0; }

echo ""
echo "==> 停止服务..."
systemctl stop paid-wifi 2>/dev/null || true
systemctl disable paid-wifi 2>/dev/null || true

echo "==> 删除 systemd..."
rm -f /etc/systemd/system/paid-wifi.service
rm -f /etc/systemd/system/paid-wifi-backup.service
rm -f /etc/systemd/system/paid-wifi-backup.timer
systemctl daemon-reload

echo "==> 删除 Nginx 配置..."
rm -f /etc/nginx/sites-available/paid-wifi
rm -f /etc/nginx/sites-enabled/paid-wifi
rm -f /etc/nginx/conf.d/paid-wifi.conf
nginx -t && systemctl reload nginx

echo "==> 备份数据..."
if [ -d /opt/paid-wifi/server/data ]; then
    BACKUP="/root/paid-wifi-data-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$BACKUP" -C /opt/paid-wifi/server data/ 2>/dev/null || true
    echo "  数据已备份到：$BACKUP"
fi

echo "==> 删除项目..."
rm -rf /opt/paid-wifi

echo ""
echo -e "${GREEN}✅ 卸载完成${NC}"
echo ""
echo "如需重新安装，运行 install.sh"