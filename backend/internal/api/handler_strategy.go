package api

import (
	"net/http"
	"time"

	"quantflow/internal/model"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func handleCreateStrategy(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Name        string         `json:"name" binding:"required"`
			Description string         `json:"description"`
			Type        string         `json:"type" binding:"required"`
			SourceCode  string         `json:"source_code"`
			Parameters  model.JSONMap  `json:"parameters"`
			Symbol      string         `json:"symbol" binding:"required"`
			Timeframe   string         `json:"timeframe" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		userID := c.GetString("user_id")
		strategy := model.Strategy{
			ID:         uuid.New(),
			UserID:     uuid.MustParse(userID),
			Name:       req.Name,
			Description: req.Description,
			Type:       req.Type,
			SourceCode: req.SourceCode,
			Parameters: req.Parameters,
			Symbol:     req.Symbol,
			Timeframe:  req.Timeframe,
			Status:     "draft",
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		}

		if err := deps.DB.CreateStrategy(strategy); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, strategy)
	}
}

func handleListStrategies(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		strategies, err := deps.DB.ListStrategies(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, strategies)
	}
}

func handleGetStrategy(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		strategy, err := deps.DB.GetStrategy(id)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "strategy not found"})
			return
		}
		c.JSON(http.StatusOK, strategy)
	}
}

func handleUpdateStrategy(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		var req struct {
			Name        string        `json:"name"`
			Description string        `json:"description"`
			SourceCode  string        `json:"source_code"`
			Parameters  model.JSONMap `json:"parameters"`
			Timeframe   string        `json:"timeframe"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if err := deps.DB.UpdateStrategy(id, req.Name, req.Description, req.SourceCode, req.Parameters, req.Timeframe); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "updated"})
	}
}

func handleStartStrategy(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		if err := deps.DB.UpdateStrategyStatus(id, "running"); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		// TODO: 通知策略引擎启动策略
		c.JSON(http.StatusOK, gin.H{"status": "started"})
	}
}

func handleStopStrategy(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		if err := deps.DB.UpdateStrategyStatus(id, "stopped"); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		// TODO: 通知策略引擎停止策略
		c.JSON(http.StatusOK, gin.H{"status": "stopped"})
	}
}

func handleStrategyPerformance(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		perf, err := deps.DB.GetStrategyPerformance(id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, perf)
	}
}

func handleBacktest(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		var req struct {
			StartDate string  `json:"start_date"`
			EndDate   string  `json:"end_date"`
			InitialCap float64 `json:"initial_capital"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// TODO: 调用 Python 策略引擎执行回测
		c.JSON(http.StatusOK, gin.H{
			"strategy_id":   id,
			"start_date":    req.StartDate,
			"end_date":      req.EndDate,
			"initial_capital": req.InitialCap,
			"status":        "pending",
			"message":       "backtest queued",
		})
	}
}

func handleListTrades(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		trades, err := deps.DB.ListTrades(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, trades)
	}
}

func handlePositions(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		positions, err := deps.DB.GetPositions(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, positions)
	}
}
