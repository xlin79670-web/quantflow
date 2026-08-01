.PHONY: help dev prod deploy stop logs backup clean

help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ==================== 开发环境 ====================

dev: ## 启动开发环境
	docker compose up -d
	@echo "✅ 开发环境已启动"
	@echo "   后端: http://localhost:8080"
	@echo "   AI:   http://localhost:8000"

dev-down: ## 停止开发环境
	docker compose down

dev-logs: ## 查看开发日志
	docker compose logs -f

# ==================== 生产环境 ====================

prod: ## 启动生产环境
	docker compose -f docker-compose.prod.yml up -d --build
	@echo "✅ 生产环境已启动"

prod-down: ## 停止生产环境
	docker compose -f docker-compose.prod.yml down

prod-logs: ## 查看生产日志
	docker compose -f docker-compose.prod.yml logs -f

prod-ps: ## 查看生产状态
	docker compose -f docker-compose.prod.yml ps

deploy: ## 一键部署
	@chmod +x deploy/scripts/*.sh
	@./deploy/scripts/deploy.sh

# ==================== 数据库 ====================

db-shell: ## 进入数据库 Shell
	docker compose exec postgres psql -U quantflow quantflow

db-backup: ## 手动备份数据库
	@mkdir -p backups
	docker compose exec postgres pg_dump -U quantflow quantflow | gzip > backups/quantflow_$$(date +%Y%m%d_%H%M%S).sql.gz
	@echo "✅ 备份已保存到 backups/"

db-restore: ## 恢复数据库 (用法: make db-restore FILE=backup.sql.gz)
	@test -f $(FILE) || (echo "❌ 文件不存在: $(FILE)" && exit 1)
	gunzip -c $(FILE) | docker compose exec -T postgres psql -U quantflow quantflow
	@echo "✅ 数据库已恢复"

# ==================== 工具 ====================

logs: ## 查看所有日志
	docker compose logs -f

logs-backend: ## 查看后端日志
	docker compose logs -f backend

logs-ai: ## 查看 AI 引擎日志
	docker compose logs -f ai-engine

logs-bridge: ## 查看 MT Bridge 日志
	docker compose logs -f mt-bridge

restart: ## 重启所有服务
	docker compose restart

restart-backend: ## 重启后端
	docker compose restart backend

restart-ai: ## 重启 AI 引擎
	docker compose restart ai-engine

# ==================== 清理 ====================

clean: ## 清理所有容器和数据
	@echo "⚠️  这将删除所有容器和数据!"
	@read -p "确认? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose -f docker-compose.prod.yml down -v
	docker compose down -v
	docker system prune -f
	@echo "✅ 清理完成"

# ==================== SSL ====================

ssl-selfsigned: ## 生成自签名证书
	@mkdir -p deploy/nginx/ssl
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout deploy/nginx/ssl/privkey.pem \
		-out deploy/nginx/ssl/fullchain.pem \
		-subj "/CN=localhost"
	@echo "✅ 自签名证书已生成"

ssl-renew: ## 续期 Let's Encrypt 证书
	sudo certbot renew
	docker compose restart nginx
