package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"quantflow/internal/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Postgres struct {
	pool *pgxpool.Pool
}

func NewPostgres(databaseURL string) (*Postgres, error) {
	pool, err := pgxpool.New(context.Background(), databaseURL)
	if err != nil {
		return nil, fmt.Errorf("unable to connect: %w", err)
	}
	if err := pool.Ping(context.Background()); err != nil {
		return nil, fmt.Errorf("ping failed: %w", err)
	}
	return &Postgres{pool: pool}, nil
}

func (p *Postgres) Close() {
	p.pool.Close()
}

// ==================== 用户 ====================

func (p *Postgres) CreateUser(u model.User) error {
	_, err := p.pool.Exec(context.Background(),
		`INSERT INTO users (id, email, password_hash, nickname, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		u.ID, u.Email, u.PasswordHash, u.Nickname, u.CreatedAt, u.UpdatedAt)
	return err
}

func (p *Postgres) GetUserByID(id string) (*model.User, error) {
	var u model.User
	err := p.pool.QueryRow(context.Background(),
		`SELECT id, email, password_hash, nickname, created_at, updated_at
		 FROM users WHERE id = $1`, id).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Nickname, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (p *Postgres) GetUserByEmail(email string) (*model.User, error) {
	var u model.User
	err := p.pool.QueryRow(context.Background(),
		`SELECT id, email, password_hash, nickname, created_at, updated_at
		 FROM users WHERE email = $1`, email).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Nickname, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// ==================== 策略 ====================

func (p *Postgres) CreateStrategy(s model.Strategy) error {
	paramsJSON, _ := json.Marshal(s.Parameters)
	_, err := p.pool.Exec(context.Background(),
		`INSERT INTO strategies (id, user_id, name, description, type, source_code, parameters, symbol, timeframe, status, is_ai_generated, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
		s.ID, s.UserID, s.Name, s.Description, s.Type, s.SourceCode, paramsJSON,
		s.Symbol, s.Timeframe, s.Status, s.IsAIGenerated, s.CreatedAt, s.UpdatedAt)
	return err
}

func (p *Postgres) ListStrategies(userID string) ([]model.Strategy, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT id, user_id, name, description, type, source_code, parameters, symbol, timeframe, status, is_ai_generated, created_at, updated_at
		 FROM strategies WHERE user_id = $1 ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var strategies []model.Strategy
	for rows.Next() {
		var s model.Strategy
		var paramsJSON []byte
		err := rows.Scan(&s.ID, &s.UserID, &s.Name, &s.Description, &s.Type, &s.SourceCode,
			&paramsJSON, &s.Symbol, &s.Timeframe, &s.Status, &s.IsAIGenerated, &s.CreatedAt, &s.UpdatedAt)
		if err != nil {
			continue
		}
		json.Unmarshal(paramsJSON, &s.Parameters)
		strategies = append(strategies, s)
	}
	return strategies, nil
}

func (p *Postgres) GetStrategy(id string) (*model.Strategy, error) {
	var s model.Strategy
	var paramsJSON []byte
	err := p.pool.QueryRow(context.Background(),
		`SELECT id, user_id, name, description, type, source_code, parameters, symbol, timeframe, status, is_ai_generated, created_at, updated_at
		 FROM strategies WHERE id = $1`, id).Scan(
		&s.ID, &s.UserID, &s.Name, &s.Description, &s.Type, &s.SourceCode,
		&paramsJSON, &s.Symbol, &s.Timeframe, &s.Status, &s.IsAIGenerated, &s.CreatedAt, &s.UpdatedAt)
	if err != nil {
		return nil, err
	}
	json.Unmarshal(paramsJSON, &s.Parameters)
	return &s, nil
}

func (p *Postgres) UpdateStrategy(id, name, desc, code string, params model.JSONMap, tf string) error {
	paramsJSON, _ := json.Marshal(params)
	_, err := p.pool.Exec(context.Background(),
		`UPDATE strategies SET name=$1, description=$2, source_code=$3, parameters=$4, timeframe=$5, updated_at=$6 WHERE id=$7`,
		name, desc, code, paramsJSON, tf, time.Now(), id)
	return err
}

func (p *Postgres) UpdateStrategyStatus(id, status string) error {
	_, err := p.pool.Exec(context.Background(),
		`UPDATE strategies SET status=$1, updated_at=$2 WHERE id=$3`,
		status, time.Now(), id)
	return err
}

func (p *Postgres) GetStrategyPerformance(id string) ([]model.StrategyPerformance, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT id, strategy_id, date, total_return, daily_return, max_drawdown, sharpe_ratio,
		 win_rate, total_trades, winning_trades, losing_trades, profit_factor, avg_win, avg_loss
		 FROM strategy_performance WHERE strategy_id = $1 ORDER BY date DESC`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var perfs []model.StrategyPerformance
	for rows.Next() {
		var p model.StrategyPerformance
		if err := rows.Scan(&p.ID, &p.StrategyID, &p.Date, &p.TotalReturn, &p.DailyReturn,
			&p.MaxDrawdown, &p.SharpeRatio, &p.WinRate, &p.TotalTrades, &p.WinningTrades,
			&p.LosingTrades, &p.ProfitFactor, &p.AvgWin, &p.AvgLoss); err != nil {
			continue
		}
		perfs = append(perfs, p)
	}
	return perfs, nil
}

// ==================== 交易 ====================

func (p *Postgres) ListTrades(userID string) ([]model.Trade, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT t.id, t.strategy_id, t.account_id, t.symbol, t.side, t.type, t.quantity, t.price,
		 t.stop_price, t.status, t.exchange_id, t.fee, t.pnl, t.signal_data, t.executed_at, t.created_at
		 FROM trades t JOIN strategies s ON t.strategy_id = s.id
		 WHERE s.user_id = $1 ORDER BY t.created_at DESC LIMIT 100`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanTrades(rows)
}

func (p *Postgres) ListTradesByStrategy(strategyID string) ([]model.Trade, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT id, strategy_id, account_id, symbol, side, type, quantity, price,
		 stop_price, status, exchange_id, fee, pnl, signal_data, executed_at, created_at
		 FROM trades WHERE strategy_id = $1 ORDER BY created_at DESC`, strategyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanTrades(rows)
}

func scanTrades(rows pgx.Rows) ([]model.Trade, error) {
	var trades []model.Trade
	for rows.Next() {
		var t model.Trade
		var signalJSON []byte
		if err := rows.Scan(&t.ID, &t.StrategyID, &t.AccountID, &t.Symbol, &t.Side, &t.Type,
			&t.Quantity, &t.Price, &t.StopPrice, &t.Status, &t.ExchangeID, &t.Fee, &t.PnL,
			&signalJSON, &t.ExecutedAt, &t.CreatedAt); err != nil {
			continue
		}
		json.Unmarshal(signalJSON, &t.SignalData)
		trades = append(trades, t)
	}
	return trades, nil
}

func (p *Postgres) GetPositions(userID string) ([]model.Position, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT pos.id, pos.account_id, pos.strategy_id, pos.symbol, pos.side, pos.quantity,
		 pos.entry_price, pos.mark_price, pos.pnl, pos.pnl_percent, pos.updated_at
		 FROM positions pos JOIN strategies s ON pos.strategy_id = s.id
		 WHERE s.user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var positions []model.Position
	for rows.Next() {
		var pos model.Position
		if err := rows.Scan(&pos.ID, &pos.AccountID, &pos.StrategyID, &pos.Symbol, &pos.Side,
			&pos.Quantity, &pos.EntryPrice, &pos.MarkPrice, &pos.PnL, &pos.PnLPercent, &pos.UpdatedAt); err != nil {
			continue
		}
		positions = append(positions, pos)
	}
	return positions, nil
}

// ==================== 交易所账户 ====================

func (p *Postgres) CreateAccount(a model.ExchangeAccount) error {
	_, err := p.pool.Exec(context.Background(),
		`INSERT INTO exchange_accounts (id, user_id, exchange, label, api_key_enc, api_secret_enc, is_active, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		a.ID, a.UserID, a.Exchange, a.Label, a.APIKeyEnc, a.APISecretEnc, a.IsActive, a.CreatedAt)
	return err
}

func (p *Postgres) ListAccounts(userID string) ([]model.ExchangeAccount, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT id, user_id, exchange, label, is_active, created_at
		 FROM exchange_accounts WHERE user_id = $1 ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var accounts []model.ExchangeAccount
	for rows.Next() {
		var a model.ExchangeAccount
		if err := rows.Scan(&a.ID, &a.UserID, &a.Exchange, &a.Label, &a.IsActive, &a.CreatedAt); err != nil {
			continue
		}
		accounts = append(accounts, a)
	}
	return accounts, nil
}

// ==================== AI 对话 ====================

func (p *Postgres) SaveChatMessage(msg model.AIChatMessage) error {
	_, err := p.pool.Exec(context.Background(),
		`INSERT INTO ai_chat_messages (id, user_id, role, content, context, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		msg.ID, msg.UserID, msg.Role, msg.Content, msg.Context, msg.CreatedAt)
	return err
}

func (p *Postgres) GetRecentInsights(limit int) ([]model.AIMarketInsight, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT id, symbol, sentiment, impact_score, summary, source, source_url, created_at
		 FROM ai_market_insights ORDER BY created_at DESC LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var insights []model.AIMarketInsight
	for rows.Next() {
		var i model.AIMarketInsight
		if err := rows.Scan(&i.ID, &i.Symbol, &i.Sentiment, &i.ImpactScore, &i.Summary, &i.Source, &i.SourceURL, &i.CreatedAt); err != nil {
			continue
		}
		insights = append(insights, i)
	}
	return insights, nil
}

// ==================== 数据分析 ====================

func (p *Postgres) GetAnalyticsOverview(userID string) (map[string]interface{}, error) {
	// 查询总收益、总交易数、胜率等
	var totalReturn float64
	var totalTrades int
	var winRate float64

	p.pool.QueryRow(context.Background(),
		`SELECT COALESCE(SUM(t.pnl), 0), COUNT(t.id)
		 FROM trades t JOIN strategies s ON t.strategy_id = s.id
		 WHERE s.user_id = $1 AND t.status = 'filled'`, userID).Scan(&totalReturn, &totalTrades)

	p.pool.QueryRow(context.Background(),
		`SELECT CASE WHEN COUNT(*) > 0 THEN
			COUNT(CASE WHEN t.pnl > 0 THEN 1 END)::float / COUNT(*)::float * 100
		 ELSE 0 END
		 FROM trades t JOIN strategies s ON t.strategy_id = s.id
		 WHERE s.user_id = $1 AND t.status = 'filled'`, userID).Scan(&winRate)

	return map[string]interface{}{
		"total_return": totalReturn,
		"total_trades": totalTrades,
		"win_rate":     winRate,
	}, nil
}

func (p *Postgres) GetEquityCurve(userID string) ([]map[string]interface{}, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT date, daily_return FROM strategy_performance sp
		 JOIN strategies s ON sp.strategy_id = s.id
		 WHERE s.user_id = $1 ORDER BY sp.date`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var curve []map[string]interface{}
	cumulative := 10000.0 // 假设初始资金 10000
	for rows.Next() {
		var date string
		var dailyReturn float64
		if err := rows.Scan(&date, &dailyReturn); err != nil {
			continue
		}
		cumulative *= (1 + dailyReturn/100)
		curve = append(curve, map[string]interface{}{
			"date":      date,
			"equity":    cumulative,
			"return":    dailyReturn,
		})
	}
	return curve, nil
}
