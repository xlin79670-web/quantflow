package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"quantflow/internal/model"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// handleAIChat AI 对话接口
func handleAIChat(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Message string `json:"message" binding:"required"`
			Context string `json:"context"` // 可选：附加上下文
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		userID := c.GetString("user_id")

		// 获取用户策略和交易数据作为上下文
		strategies, _ := deps.DB.ListStrategies(userID)
		recentTrades, _ := deps.DB.ListTrades(userID)

		// 构建发给 AI 服务的请求
		aiReq := map[string]interface{}{
			"message":    req.Message,
			"user_id":    userID,
			"strategies": strategies,
			"trades":     recentTrades,
			"context":    req.Context,
		}

		// 调用 Python AI 服务
		resp, err := callAIService(deps.Config.AIServiceURL+"/api/chat", aiReq)
		if err != nil {
			deps.Logger.Errorf("AI service error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":   "AI service unavailable",
				"message": "AI 暂时无法响应，请稍后重试",
			})
			return
		}

		// 保存对话记录
		deps.DB.SaveChatMessage(model.AIChatMessage{
			ID:      uuid.New(),
			UserID:  uuid.MustParse(userID),
			Role:    "user",
			Content: req.Message,
		})
		deps.DB.SaveChatMessage(model.AIChatMessage{
			ID:      uuid.New(),
			UserID:  uuid.MustParse(userID),
			Role:    "assistant",
			Content: resp["response"].(string),
		})

		c.JSON(http.StatusOK, resp)
	}
}

// handleAIGenerateStrategy AI 生成策略
func handleAIGenerateStrategy(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Description string `json:"description" binding:"required"`
			Symbol      string `json:"symbol"`
			Timeframe   string `json:"timeframe"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		userID := c.GetString("user_id")

		aiReq := map[string]interface{}{
			"description": req.Description,
			"symbol":      req.Symbol,
			"timeframe":   req.Timeframe,
			"user_id":     userID,
		}

		resp, err := callAIService(deps.Config.AIServiceURL+"/api/generate-strategy", aiReq)
		if err != nil {
			deps.Logger.Errorf("AI generate error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate strategy"})
			return
		}

		// 自动保存生成的策略
		if code, ok := resp["source_code"].(string); ok && code != "" {
			strategy := model.Strategy{
				ID:            uuid.New(),
				UserID:        uuid.MustParse(userID),
				Name:          resp["name"].(string),
				Description:   resp["description"].(string),
				Type:          "custom",
				SourceCode:    code,
				Parameters:    resp["parameters"].(model.JSONMap),
				Symbol:        req.Symbol,
				Timeframe:     req.Timeframe,
				Status:        "draft",
				IsAIGenerated: true,
			}
			deps.DB.CreateStrategy(strategy)
			resp["strategy_id"] = strategy.ID
		}

		c.JSON(http.StatusOK, resp)
	}
}

// handleMarketInsights 获取市场洞察
func handleMarketInsights(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		insights, err := deps.DB.GetRecentInsights(20)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, insights)
	}
}

// handleAIOptimizeStrategy AI 优化策略
func handleAIOptimizeStrategy(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		strategy, err := deps.DB.GetStrategy(id)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "strategy not found"})
			return
		}

		performance, _ := deps.DB.GetStrategyPerformance(id)
		recentTrades, _ := deps.DB.ListTradesByStrategy(id)

		aiReq := map[string]interface{}{
			"strategy":    strategy,
			"performance": performance,
			"trades":      recentTrades,
		}

		resp, err := callAIService(deps.Config.AIServiceURL+"/api/optimize-strategy", aiReq)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "optimization failed"})
			return
		}

		c.JSON(http.StatusOK, resp)
	}
}

// handleAnalyticsOverview 数据分析概览
func handleAnalyticsOverview(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		overview, err := deps.DB.GetAnalyticsOverview(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, overview)
	}
}

// handleEquityCurve 权益曲线
func handleEquityCurve(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		curve, err := deps.DB.GetEquityCurve(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, curve)
	}
}

// ==================== 工具函数 ====================

func callAIService(url string, payload interface{}) (map[string]interface{}, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	resp, err := http.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("AI service request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("AI service returned %d: %s", resp.StatusCode, string(respBody))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, err
	}
	return result, nil
}
