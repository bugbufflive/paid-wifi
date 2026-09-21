paid-wifi/
├── README.md
├── .gitignore
├── package.json                    # 根项目（管理脚本）
├── server/                         # 服务端（Node.js）
│   ├── package.json
│   ├── .env.example
│   ├── Dockerfile
│   └── src/
│       ├── app.js
│       ├── db.js
│       ├── config.js
│       ├── middleware/
│       │   ├── auth.js
│       │   └── routerAuth.js
│       └── routes/
│           ├── public.js
│           ├── admin.js
│           ├── router.js
│           └── auth.js
├── worker/                         # Cloudflare Worker
│   ├── wrangler.toml
│   ├── package.json
│   └── src/
│       └── index.js
├── router/                         # 路由器端
│   ├── install.sh
│   ├── config.example.sh
│   ├── paid_wifi.init
│   ├── bin/
│   │   ├── daemon.sh
│   │   ├── poll.sh
│   │   ├── heartbeat.sh
│   │   ├── rules.sh
│   │   ├── allow.sh
│   │   ├── enforce.sh
│   │   ├── restore.sh
│   │   └── pw
│   └── portal/
│       └── index.html
├── deploy/
│   ├── deploy.sh                   # 一键部署（VPS 上运行）
│   ├── setup-vps.sh                # VPS 初始化
│   ├── nginx.conf
│   └── paid-wifi.service
└── .github/
    └── workflows/
        └── deploy.yml