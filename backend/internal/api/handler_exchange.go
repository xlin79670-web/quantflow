package api

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

func handleTicker(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		symbol := c.Param("symbol")
		ticker, err := deps.BinanceClient.GetTicker(symbol)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, ticker)
	}
}

func handleKlines(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		symbol := c.Param("symbol")
		interval := c.DefaultQuery("interval", "1h")
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))

		klines, err := deps.BinanceClient.GetKlines(symbol, interval, limit)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, klines)
	}
}

func handleBalances(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		balances, err := deps.BinanceClient.GetBalances()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, balances)
	}
}

func handlePlaceOrder(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Symbol   string  `json:"symbol" binding:"required"`
			Side     string  `json:"side" binding:"required"` // buy, sell
			Type     string  `json:"type" binding:"required"` // MARKET, LIMIT
			Quantity float64 `json:"quantity" binding:"required"`
			Price    float64 `json:"price"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		result, err := deps.BinanceClient.PlaceOrder(req.Symbol, req.Side, req.Type, req.Quantity, req.Price)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
	}
}

func handleCancelOrder(deps Deps) gin.HandlerFunc {
	return func(c *gin.Context) {
		symbol := c.Param("symbol")
		orderID, _ := strconv.ParseInt(c.Param("orderId"), 10, 64)

		result, err := deps.BinanceClient.CancelOrder(symbol, orderID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
	}
}
