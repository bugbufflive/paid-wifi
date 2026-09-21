# 付费WiFi系统文档

一套完整的付费WiFi解决方案，涵盖服务端、Cloudflare Worker、路由器端。

## 快速导航

| 文档 | 适合谁 | 内容 |
|------|--------|------|
| [架构说明](architecture.md) | 开发者 | 系统组成、数据流、端口 |
| [部署手册](deployment.md) | 运维 | VPS 部署、HTTPS、systemd |
| [API 文档](api.md) | 开发者 | 所有接口、请求响应示例 |
| [路由器配置](router-setup.md) | 运维 | 一键安装、配置文件、命令 |
| [Worker 配置](worker-setup.md) | 运维 | Cloudflare 部署、路由绑定 |
| [故障排查](troubleshooting.md) | 运维 | 常见问题、日志查看 |
| [常见问题](faq.md) | 所有人 | 场景、成本、选型 |
| [安全建议](security.md) | 运维 | SSH、防火墙、Token |
| [备份恢复](backup.md) | 运维 | rclone、systemd timer |
| [更新日志](changelog.md) | 所有人 | 版本历史 |

## 5 分钟上手

```bash
# 1. 部署服务端
git clone https://github.com/your-username/paid-wifi.git
cd paid-wifi
sudo bash deploy/setup-vps.sh

# 2. 部署 Worker
cd worker && npm install && npx wrangler deploy

# 3. 部署路由器端
# 在路由器上执行：
wget -O - https://raw.githubusercontent.com/your-username/paid-wifi/main/router/install.sh | sh