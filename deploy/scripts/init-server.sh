#!/bin/bash
# QuantFlow 快速初始化脚本 (新服务器用)

set -e

echo "🚀 QuantFlow 服务器初始化"
echo "========================="

# 1. 系统更新
echo "📦 更新系统..."
sudo apt update && sudo apt upgrade -y

# 2. 安装 Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 安装 Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "✅ Docker 已安装 (需要重新登录生效)"
else
    echo "✅ Docker 已安装"
fi

# 3. 安装必要工具
echo "📦 安装工具..."
sudo apt install -y git curl wget make openssl

# 4. 克隆项目 (如果还没有)
if [ ! -d "quantflow" ]; then
    echo "📥 克隆项目..."
    # git clone <repo-url> quantflow
    echo "请手动克隆项目"
fi

cd quantflow 2>/dev/null || exit 1

# 5. 生成环境变量
if [ ! -f .env ]; then
    echo "⚙️  生成环境变量..."
    cp .env.production .env

    # 自动生成密钥
    JWT_SECRET=$(openssl rand -hex 32)
    PG_PASSWORD=$(openssl rand -hex 16)

    sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$PG_PASSWORD/" .env

    echo "✅ .env 已生成"
    echo ""
    echo "⚠️  请编辑 .env 填入以下 API Key:"
    echo "   - BINANCE_API_KEY"
    echo "   - BINANCE_SECRET_KEY"
    echo "   - DEEPSEEK_API_KEY"
    echo "   - QWEN_API_KEY"
    echo ""
    echo "vim .env"
else
    echo "✅ .env 已存在"
fi

# 6. 创建目录
mkdir -p backups deploy/nginx/ssl

echo ""
echo "✅ 初始化完成!"
echo ""
echo "下一步:"
echo "  1. 编辑 .env 填入 API Key"
echo "  2. 运行: make deploy"
echo ""
