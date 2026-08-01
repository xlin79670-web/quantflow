# QuantFlow 生产部署指南

## 架构

```
                    ┌─────────────┐
                    │   Cloudflare │
                    │   (DNS+CDN) │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │    Nginx    │
                    │ (SSL终结)   │
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────┴──────┐  ┌─────┴──────┐  ┌──────┴──────┐
   │   Go API    │  │  AI Engine │  │  MT Bridge  │
   │  :8080      │  │  :8000     │  │  :9090      │
   └──────┬──────┘  └─────┬──────┘  └──────┬──────┘
          │               │                │
   ┌──────┴───────────────┴────────────────┘
   │
   ├── PostgreSQL :5432
   └── Redis :6379
```

## 服务器要求

| 项目 | 最低 | 推荐 |
|------|------|------|
| CPU | 2 核 | 4 核 |
| 内存 | 4 GB | 8 GB |
| 硬盘 | 40 GB SSD | 100 GB SSD |
| 带宽 | 5 Mbps | 10 Mbps |
| 系统 | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |

## 快速部署 (3 步)

```bash
# 1. 克隆项目
git clone <repo-url> quantflow
cd quantflow

# 2. 配置环境变量
cp .env.example .env
vim .env  # 填入真实 API Key

# 3. 一键部署
chmod +x deploy/scripts/*.sh
./deploy/scripts/deploy.sh
```

## 详细步骤

### 1. 服务器初始化

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo apt install docker-compose-plugin -y

# 验证
docker --version
docker compose version
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`:

```env
# 必填
JWT_SECRET=<随机32位字符串>
BINANCE_API_KEY=<你的币安API Key>
BINANCE_SECRET_KEY=<你的币安Secret Key>
DEEPSEEK_API_KEY=<DeepSeek API Key>
QWEN_API_KEY=<通义千问 API Key>

# 可选
BRIDGE_PORT=9090
DOMAIN=your-domain.com
```

### 3. 部署

```bash
# 构建并启动
docker compose -f docker-compose.prod.yml up -d --build

# 查看状态
docker compose -f docker-compose.prod.yml ps

# 查看日志
docker compose -f docker-compose.prod.yml logs -f
```

### 4. SSL 证书 (Let's Encrypt)

```bash
# 安装 certbot
sudo apt install certbot python3-certbot-nginx -y

# 获取证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

### 5. 域名配置

DNS 记录:
```
A     your-domain.com      → 服务器 IP
A     api.your-domain.com  → 服务器 IP
A     ws.your-domain.com   → 服务器 IP
```

## 监控

```bash
# 查看容器状态
docker compose -f docker-compose.prod.yml ps

# 查看资源使用
docker stats

# 查看日志
docker compose -f docker-compose.prod.yml logs -f backend
docker compose -f docker-compose.prod.yml logs -f ai-engine
```

## 备份

```bash
# 数据库备份 (每天自动)
./deploy/scripts/backup.sh

# 手动备份
docker compose -f docker-compose.prod.yml exec postgres pg_dump -U quantflow quantflow > backup.sql
```

## 更新

```bash
# 拉取最新代码
git pull

# 重新部署
./deploy/scripts/deploy.sh
```
