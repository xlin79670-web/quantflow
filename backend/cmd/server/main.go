package main

import (
	"log"
	"os"

	"quantflow/internal/api"
	"quantflow/internal/config"
	"quantflow/internal/exchange/binance"
	"quantflow/internal/repository"

	"github.com/joho/godotenv"
	"go.uber.org/zap"
)

func main() {
	// 加载环境变量
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system env")
	}

	// 初始化日志
	logger, _ := zap.NewProduction()
	defer logger.Sync()
	sugar := logger.Sugar()

	// 加载配置
	cfg := config.Load()

	// 初始化数据库
	db, err := repository.NewPostgres(cfg.DatabaseURL)
	if err != nil {
		sugar.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// 初始化 Redis
	rdb := repository.NewRedis(cfg.RedisURL)
	defer rdb.Close()

	// 初始化币安客户端
	binanceClient := binance.NewClient(
		cfg.BinanceAPIKey,
		cfg.BinanceSecretKey,
		cfg.BinanceBaseURL,
	)

	// 初始化路由
	router := api.NewRouter(api.Deps{
		Config:         cfg,
		DB:             db,
		Redis:          rdb,
		BinanceClient:  binanceClient,
		Logger:         sugar,
	})

	// 启动服务
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	sugar.Infof("QuantFlow server starting on :%s", port)
	if err := router.Run(":" + port); err != nil {
		sugar.Fatalf("Server failed: %v", err)
	}
}
