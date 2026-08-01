package api

import (
	"quantflow/internal/config"
	"quantflow/internal/exchange/binance"
	"quantflow/internal/repository"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type Deps struct {
	Config        *config.Config
	DB            *repository.Postgres
	Redis         *repository.Redis
	BinanceClient *binance.Client
	Logger        *zap.SugaredLogger
}

func NewRouter(deps Deps) *gin.Engine {
	r := gin.Default()

	// CORS
	r.Use(corsMiddleware())

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "quantflow"})
	})

	api := r.Group("/api/v1")

	// 公开路由
	auth := api.Group("/auth")
	{
		auth.POST("/register", handleRegister(deps))
		auth.POST("/login", handleLogin(deps))
	}

	// 需要认证的路由
	protected := api.Group("")
	protected.Use(authMiddleware(deps.Config.JWTSecret))
	{
		// 用户
		protected.GET("/user/profile", handleProfile(deps))

		// 交易所
		exchange := protected.Group("/exchange")
		{
			exchange.POST("/accounts", handleAddAccount(deps))
			exchange.GET("/accounts", handleListAccounts(deps))
			exchange.GET("/accounts/:id/balances", handleBalances(deps))
			exchange.GET("/ticker/:symbol", handleTicker(deps))
			exchange.GET("/klines/:symbol", handleKlines(deps))
			exchange.POST("/orders", handlePlaceOrder(deps))
			exchange.DELETE("/orders/:symbol/:orderId", handleCancelOrder(deps))
		}

		// 策略
		strategy := protected.Group("/strategy")
		{
			strategy.POST("", handleCreateStrategy(deps))
			strategy.GET("", handleListStrategies(deps))
			strategy.GET("/:id", handleGetStrategy(deps))
			strategy.PUT("/:id", handleUpdateStrategy(deps))
			strategy.POST("/:id/start", handleStartStrategy(deps))
			strategy.POST("/:id/stop", handleStopStrategy(deps))
			strategy.GET("/:id/performance", handleStrategyPerformance(deps))
			strategy.POST("/:id/backtest", handleBacktest(deps))
		}

		// 交易
		trading := protected.Group("/trades")
		{
			trading.GET("", handleListTrades(deps))
			trading.GET("/positions", handlePositions(deps))
		}

		// AI
		ai := protected.Group("/ai")
		{
			ai.POST("/chat", handleAIChat(deps))
			ai.POST("/generate-strategy", handleAIGenerateStrategy(deps))
			ai.GET("/insights", handleMarketInsights(deps))
			ai.POST("/optimize/:id", handleAIOptimizeStrategy(deps))
		}

		// 数据分析
		analytics := protected.Group("/analytics")
		{
			analytics.GET("/overview", handleAnalyticsOverview(deps))
			analytics.GET("/equity-curve", handleEquityCurve(deps))
		}
	}

	return r
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}
