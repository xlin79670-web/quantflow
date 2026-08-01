-- QuantFlow 数据库初始化脚本

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 交易所账户表
CREATE TABLE IF NOT EXISTS exchange_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exchange VARCHAR(20) NOT NULL, -- binance, mt4, mt5
    label VARCHAR(100),
    api_key_enc TEXT NOT NULL,
    api_secret_enc TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_exchange_accounts_user ON exchange_accounts(user_id);

-- 策略表
CREATE TABLE IF NOT EXISTS strategies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL, -- ma_cross, rsi, grid, custom
    source_code TEXT,
    parameters JSONB DEFAULT '{}',
    symbol VARCHAR(20) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    account_id UUID REFERENCES exchange_accounts(id),
    status VARCHAR(20) DEFAULT 'draft', -- draft, backtesting, running, paused, stopped
    is_ai_generated BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_strategies_user ON strategies(user_id);
CREATE INDEX idx_strategies_status ON strategies(status);

-- 交易记录表
CREATE TABLE IF NOT EXISTS trades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    strategy_id UUID NOT NULL REFERENCES strategies(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES exchange_accounts(id),
    symbol VARCHAR(20) NOT NULL,
    side VARCHAR(10) NOT NULL, -- buy, sell
    type VARCHAR(20) NOT NULL, -- market, limit, stop
    quantity DECIMAL(20, 8) NOT NULL,
    price DECIMAL(20, 8) NOT NULL,
    stop_price DECIMAL(20, 8),
    status VARCHAR(20) DEFAULT 'pending', -- pending, filled, cancelled, rejected
    exchange_id VARCHAR(100),
    fee DECIMAL(20, 8) DEFAULT 0,
    pnl DECIMAL(20, 8),
    signal_data JSONB DEFAULT '{}',
    executed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_trades_strategy ON trades(strategy_id);
CREATE INDEX idx_trades_symbol ON trades(symbol);
CREATE INDEX idx_trades_created ON trades(created_at DESC);

-- 持仓表
CREATE TABLE IF NOT EXISTS positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES exchange_accounts(id),
    strategy_id UUID NOT NULL REFERENCES strategies(id) ON DELETE CASCADE,
    symbol VARCHAR(20) NOT NULL,
    side VARCHAR(10) NOT NULL,
    quantity DECIMAL(20, 8) NOT NULL,
    entry_price DECIMAL(20, 8) NOT NULL,
    mark_price DECIMAL(20, 8) NOT NULL,
    pnl DECIMAL(20, 8) DEFAULT 0,
    pnl_percent DECIMAL(10, 4) DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_positions_strategy ON positions(strategy_id);

-- 策略性能记录表
CREATE TABLE IF NOT EXISTS strategy_performance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    strategy_id UUID NOT NULL REFERENCES strategies(id) ON DELETE CASCADE,
    date VARCHAR(10) NOT NULL,
    total_return DECIMAL(10, 4) DEFAULT 0,
    daily_return DECIMAL(10, 4) DEFAULT 0,
    max_drawdown DECIMAL(10, 4) DEFAULT 0,
    sharpe_ratio DECIMAL(10, 4) DEFAULT 0,
    win_rate DECIMAL(10, 4) DEFAULT 0,
    total_trades INT DEFAULT 0,
    winning_trades INT DEFAULT 0,
    losing_trades INT DEFAULT 0,
    profit_factor DECIMAL(10, 4) DEFAULT 0,
    avg_win DECIMAL(10, 4) DEFAULT 0,
    avg_loss DECIMAL(10, 4) DEFAULT 0,
    UNIQUE(strategy_id, date)
);
CREATE INDEX idx_perf_strategy ON strategy_performance(strategy_id, date DESC);

-- AI 对话记录表
CREATE TABLE IF NOT EXISTS ai_chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL, -- user, assistant, system
    content TEXT NOT NULL,
    context JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_chat_user ON ai_chat_messages(user_id, created_at DESC);

-- AI 市场洞察表
CREATE TABLE IF NOT EXISTS ai_market_insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20),
    sentiment VARCHAR(20), -- bullish, bearish, neutral
    impact_score INT DEFAULT 0,
    summary TEXT NOT NULL,
    source VARCHAR(100),
    source_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_insights_created ON ai_market_insights(created_at DESC);
CREATE INDEX idx_insights_symbol ON ai_market_insights(symbol);

-- 策略进化记录表
CREATE TABLE IF NOT EXISTS strategy_evolutions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    strategy_id UUID NOT NULL REFERENCES strategies(id) ON DELETE CASCADE,
    variant_name VARCHAR(200),
    original_params JSONB,
    evolved_params JSONB,
    original_return DECIMAL(10, 4),
    evolved_return DECIMAL(10, 4),
    improvement DECIMAL(10, 4),
    status VARCHAR(20) DEFAULT 'pending', -- pending, testing, accepted, rejected
    ai_reasoning TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_evolutions_strategy ON strategy_evolutions(strategy_id, created_at DESC);
