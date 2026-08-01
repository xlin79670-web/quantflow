package model

import (
	"time"

	"github.com/google/uuid"
)

// ==================== 用户 ====================

type User struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	Email        string     `json:"email" db:"email"`
	PasswordHash string     `json:"-" db:"password_hash"`
	Nickname     string     `json:"nickname" db:"nickname"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}

// ==================== 交易所账户 ====================

type ExchangeAccount struct {
	ID           uuid.UUID `json:"id" db:"id"`
	UserID       uuid.UUID `json:"user_id" db:"user_id"`
	Exchange     string    `json:"exchange" db:"exchange"` // binance, mt4, mt5
	Label        string    `json:"label" db:"label"`
	APIKeyEnc    string    `json:"-" db:"api_key_enc"`
	APISecretEnc string    `json:"-" db:"api_secret_enc"`
	IsActive     bool      `json:"is_active" db:"is_active"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// ==================== 策略 ====================

type Strategy struct {
	ID            uuid.UUID  `json:"id" db:"id"`
	UserID        uuid.UUID  `json:"user_id" db:"user_id"`
	Name          string     `json:"name" db:"name"`
	Description   string     `json:"description" db:"description"`
	Type          string     `json:"type" db:"type"` // ma_cross, rsi, grid, custom
	SourceCode    string     `json:"source_code" db:"source_code"`
	Parameters    JSONMap    `json:"parameters" db:"parameters"`
	Symbol        string     `json:"symbol" db:"symbol"`     // BTCUSDT
	Timeframe     string     `json:"timeframe" db:"timeframe"` // 1m, 5m, 15m, 1h, 4h, 1d
	AccountID     *uuid.UUID `json:"account_id" db:"account_id"`
	Status        string     `json:"status" db:"status"` // draft, backtesting, running, paused, stopped
	IsAIGenerated bool       `json:"is_ai_generated" db:"is_ai_generated"`
	CreatedAt     time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at" db:"updated_at"`
}

// ==================== 交易 ====================

type Trade struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	StrategyID  uuid.UUID  `json:"strategy_id" db:"strategy_id"`
	AccountID   uuid.UUID  `json:"account_id" db:"account_id"`
	Symbol      string     `json:"symbol" db:"symbol"`
	Side        string     `json:"side" db:"side"` // buy, sell
	Type        string     `json:"type" db:"type"` // market, limit, stop
	Quantity    float64    `json:"quantity" db:"quantity"`
	Price       float64    `json:"price" db:"price"`
	StopPrice   *float64   `json:"stop_price" db:"stop_price"`
	Status      string     `json:"status" db:"status"` // pending, filled, cancelled, rejected
	ExchangeID  string     `json:"exchange_id" db:"exchange_id"`
	Fee         float64    `json:"fee" db:"fee"`
	PnL         *float64   `json:"pnl" db:"pnl"`
	SignalData  JSONMap    `json:"signal_data" db:"signal_data"`
	ExecutedAt  *time.Time `json:"executed_at" db:"executed_at"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
}

// ==================== 持仓 ====================

type Position struct {
	ID         uuid.UUID `json:"id" db:"id"`
	AccountID  uuid.UUID `json:"account_id" db:"account_id"`
	StrategyID uuid.UUID `json:"strategy_id" db:"strategy_id"`
	Symbol     string    `json:"symbol" db:"symbol"`
	Side       string    `json:"side" db:"side"`
	Quantity   float64   `json:"quantity" db:"quantity"`
	EntryPrice float64   `json:"entry_price" db:"entry_price"`
	MarkPrice  float64   `json:"mark_price" db:"mark_price"`
	PnL        float64   `json:"pnl" db:"pnl"`
	PnLPercent float64   `json:"pnl_percent" db:"pnl_percent"`
	UpdatedAt  time.Time `json:"updated_at" db:"updated_at"`
}

// ==================== 策略性能 ====================

type StrategyPerformance struct {
	ID             uuid.UUID `json:"id" db:"id"`
	StrategyID     uuid.UUID `json:"strategy_id" db:"strategy_id"`
	Date           string    `json:"date" db:"date"`
	TotalReturn    float64   `json:"total_return" db:"total_return"`
	DailyReturn    float64   `json:"daily_return" db:"daily_return"`
	MaxDrawdown    float64   `json:"max_drawdown" db:"max_drawdown"`
	SharpeRatio    float64   `json:"sharpe_ratio" db:"sharpe_ratio"`
	WinRate        float64   `json:"win_rate" db:"win_rate"`
	TotalTrades    int       `json:"total_trades" db:"total_trades"`
	WinningTrades  int       `json:"winning_trades" db:"winning_trades"`
	LosingTrades   int       `json:"losing_trades" db:"losing_trades"`
	ProfitFactor   float64   `json:"profit_factor" db:"profit_factor"`
	AvgWin         float64   `json:"avg_win" db:"avg_win"`
	AvgLoss        float64   `json:"avg_loss" db:"avg_loss"`
}

// ==================== K线数据 ====================

type Kline struct {
	Symbol    string    `json:"symbol"`
	Timeframe string    `json:"timeframe"`
	OpenTime  time.Time `json:"open_time"`
	Open      float64   `json:"open"`
	High      float64   `json:"high"`
	Low       float64   `json:"low"`
	Close     float64   `json:"close"`
	Volume    float64   `json:"volume"`
	Closed    bool      `json:"closed"`
}

// ==================== 行情快照 ====================

type Ticker struct {
	Symbol    string  `json:"symbol"`
	Price     float64 `json:"price"`
	Change24h float64 `json:"change_24h"`
	Volume24h float64 `json:"volume_24h"`
	High24h   float64 `json:"high_24h"`
	Low24h    float64 `json:"low_24h"`
}

// ==================== AI 相关 ====================

type AIChatMessage struct {
	ID        uuid.UUID `json:"id" db:"id"`
	UserID    uuid.UUID `json:"user_id" db:"user_id"`
	Role      string    `json:"role" db:"role"` // user, assistant, system
	Content   string    `json:"content" db:"content"`
	Context   JSONMap   `json:"context" db:"context"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type AIMarketInsight struct {
	ID          uuid.UUID `json:"id" db:"id"`
	Symbol      string    `json:"symbol" db:"symbol"`
	Sentiment   string    `json:"sentiment" db:"sentiment"` // bullish, bearish, neutral
	ImpactScore int       `json:"impact_score" db:"impact_score"`
	Summary     string    `json:"summary" db:"summary"`
	Source      string    `json:"source" db:"source"`
	SourceURL   string    `json:"source_url" db:"source_url"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// ==================== 通用类型 ====================

type JSONMap map[string]interface{}
