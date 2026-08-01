#!/bin/bash
# QuantFlow 一键部署脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.prod.yml"

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     QuantFlow 生产部署脚本           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装${NC}"
    echo "请先安装 Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker $(docker --version | cut -d' ' -f3 | tr -d ',')${NC}"
echo -e "${GREEN}✅ Docker Compose $(docker compose version --short)${NC}"

# 检查 .env
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env 文件不存在，从模板创建...${NC}"
    cp .env.example .env
    echo -e "${RED}请编辑 .env 文件填入真实的 API Key，然后重新运行此脚本${NC}"
    echo "vim .env"
    exit 1
fi

# 检查必要变量
source .env
MISSING=""
[ -z "$JWT_SECRET" ] && MISSING="$MISSING JWT_SECRET"
[ -z "$POSTGRES_PASSWORD" ] && MISSING="$MISSING POSTGRES_PASSWORD"
[ -z "$BINANCE_API_KEY" ] && MISSING="$MISSING BINANCE_API_KEY"
[ -z "$BINANCE_SECRET_KEY" ] && MISSING="$MISSING BINANCE_SECRET_KEY"

if [ -n "$MISSING" ]; then
    echo -e "${RED}❌ .env 缺少必要变量:${MISSING}${NC}"
    echo "请编辑 .env 文件补充完整"
    exit 1
fi

echo -e "${GREEN}✅ 环境变量检查通过${NC}"

# 创建必要目录
echo ""
echo -e "${BLUE}📁 创建目录...${NC}"
mkdir -p backups deploy/nginx/ssl

# 生成自签名证书 (如果不存在)
if [ ! -f deploy/nginx/ssl/fullchain.pem ]; then
    echo -e "${YELLOW}⚠️  SSL 证书不存在，生成自签名证书...${NC}"
    echo -e "${YELLOW}   生产环境请替换为 Let's Encrypt 证书${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout deploy/nginx/ssl/privkey.pem \
        -out deploy/nginx/ssl/fullchain.pem \
        -subj "/CN=localhost" 2>/dev/null
    echo -e "${GREEN}✅ 自签名证书已生成${NC}"
fi

# 停止旧容器
echo ""
echo -e "${BLUE}🛑 停止旧容器...${NC}"
docker compose -f $COMPOSE_FILE down 2>/dev/null || true

# 构建镜像
echo ""
echo -e "${BLUE}🔨 构建镜像...${NC}"
docker compose -f $COMPOSE_FILE build --no-cache

# 启动服务
echo ""
echo -e "${BLUE}🚀 启动服务...${NC}"
docker compose -f $COMPOSE_FILE up -d

# 等待服务就绪
echo ""
echo -e "${BLUE}⏳ 等待服务就绪...${NC}"
sleep 10

# 健康检查
echo ""
echo -e "${BLUE}🏥 健康检查...${NC}"

check_health() {
    local name=$1
    local url=$2
    local max_retries=10
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ $name${NC}"
            return 0
        fi
        retry=$((retry + 1))
        sleep 2
    done
    echo -e "  ${RED}❌ $name (超时)${NC}"
    return 1
}

check_health "PostgreSQL" "http://localhost:5432" || true
check_health "Redis" "http://localhost:6379" || true
check_health "Go 后端" "http://localhost:8080/health" || true
check_health "AI 引擎" "http://localhost:8000/health" || true
check_health "MT Bridge" "http://localhost:9090/health" || true

# 显示状态
echo ""
echo -e "${BLUE}📊 服务状态:${NC}"
docker compose -f $COMPOSE_FILE ps

echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ 部署完成!                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  🌐 后端 API:  http://localhost:8080"
echo -e "  🧠 AI 引擎:   http://localhost:8000"
echo -e "  🌉 MT Bridge: http://localhost:9090"
echo -e "  📊 API 文档:  http://localhost:8000/docs"
echo ""
echo -e "  📝 查看日志: docker compose -f $COMPOSE_FILE logs -f"
echo -e "  🔄 重启服务: docker compose -f $COMPOSE_FILE restart"
echo -e "  🛑 停止服务: docker compose -f $COMPOSE_FILE down"
echo ""
