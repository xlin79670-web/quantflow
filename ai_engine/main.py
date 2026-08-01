"""
QuantFlow AI Engine - 主服务入口
大模型驱动的量化交易智能分析服务
"""

import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from loguru import logger

from agents.strategy_generator import StrategyGeneratorAgent
from agents.market_analyst import MarketAnalystAgent
from agents.strategy_evolver import StrategyEvolverAgent
from agents.trading_copilot import TradingCopilotAgent
from agents.risk_predictor import RiskPredictorAgent
from llm_gateway.router import LLMRouter
from data_collector.news_collector import NewsCollector
from backtest import (
    BacktestEngine, BacktestConfig, fetch_klines, add_indicators,
    list_strategies, get_strategy, ParameterOptimizer, GeneticOptimizer,
)

load_dotenv()

# 全局实例
llm_router: LLMRouter = None
strategy_gen: StrategyGeneratorAgent = None
market_analyst: MarketAnalystAgent = None
strategy_evolver: StrategyEvolverAgent = None
trading_copilot: TradingCopilotAgent = None
risk_predictor: RiskPredictorAgent = None
news_collector: NewsCollector = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    global llm_router, strategy_gen, market_analyst, strategy_evolver
    global trading_copilot, risk_predictor, news_collector

    logger.info("🚀 Initializing QuantFlow AI Engine...")

    # 初始化 LLM 路由器
    llm_router = LLMRouter(
        deepseek_key=os.getenv("DEEPSEEK_API_KEY"),
        qwen_key=os.getenv("QWEN_API_KEY"),
        local_model=os.getenv("LOCAL_MODEL_PATH"),
    )

    # 初始化各 Agent
    strategy_gen = StrategyGeneratorAgent(llm_router)
    market_analyst = MarketAnalystAgent(llm_router)
    strategy_evolver = StrategyEvolverAgent(llm_router)
    trading_copilot = TradingCopilotAgent(llm_router)
    risk_predictor = RiskPredictorAgent(llm_router)

    # 初始化数据采集器
    news_collector = NewsCollector(llm_router)

    # 启动后台数据采集
    # asyncio.create_task(news_collector.start_continuous())

    logger.info("✅ AI Engine ready")
    yield
    logger.info("🛑 AI Engine shutting down")


app = FastAPI(
    title="QuantFlow AI Engine",
    description="大模型驱动的量化交易智能分析服务",
    version="0.1.0",
    lifespan=lifespan,
)

# 静态文件
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root():
    """返回 AI 对话界面"""
    return FileResponse("static/chat.html")


# ==================== 健康检查 ====================

@app.get("/health")
async def health():
    return {"status": "ok", "service": "quantflow-ai-engine"}


# ==================== AI 对话 ====================

@app.post("/api/chat")
async def ai_chat(request: dict):
    """
    AI 交易助手对话接口
    请求: { message, user_id, strategies?, trades?, context? }
    """
    message = request.get("message", "")
    user_id = request.get("user_id", "")
    strategies = request.get("strategies", [])
    trades = request.get("trades", [])
    context = request.get("context", "")

    result = await trading_copilot.chat(
        message=message,
        user_id=user_id,
        strategies=strategies,
        trades=trades,
        extra_context=context,
    )

    return result


# ==================== 策略生成 ====================

@app.post("/api/generate-strategy")
async def generate_strategy(request: dict):
    """
    AI 策略生成接口
    请求: { description, symbol?, timeframe?, user_id }
    """
    description = request.get("description", "")
    symbol = request.get("symbol", "BTCUSDT")
    timeframe = request.get("timeframe", "1h")

    result = await strategy_gen.generate(
        description=description,
        symbol=symbol,
        timeframe=timeframe,
    )

    return result


# ==================== 策略优化 ====================

@app.post("/api/optimize-strategy")
async def optimize_strategy(request: dict):
    """
    AI 策略优化接口
    请求: { strategy, performance?, trades? }
    """
    strategy = request.get("strategy", {})
    performance = request.get("performance", [])
    trades = request.get("trades", [])

    result = await strategy_evolver.analyze_and_suggest(
        strategy=strategy,
        performance=performance,
        trades=trades,
    )

    return result


# ==================== 市场分析 ====================

@app.post("/api/market-analysis")
async def market_analysis(request: dict):
    """
    市场分析接口
    请求: { symbol?, analysis_type? }
    """
    symbol = request.get("symbol", "BTCUSDT")
    analysis_type = request.get("analysis_type", "comprehensive")

    result = await market_analyst.analyze(
        symbol=symbol,
        analysis_type=analysis_type,
    )

    return result


# ==================== 风险评估 ====================

@app.post("/api/risk-assessment")
async def risk_assessment(request: dict):
    """
    风险评估接口
    请求: { positions?, market_data?, events? }
    """
    positions = request.get("positions", [])
    market_data = request.get("market_data", {})
    events = request.get("events", [])

    result = await risk_predictor.assess(
        positions=positions,
        market_data=market_data,
        events=events,
    )

    return result


# ==================== 市场洞察 ====================

@app.get("/api/insights")
async def get_insights(symbol: str = "BTCUSDT", limit: int = 20):
    """获取最新市场洞察"""
    insights = await market_analyst.get_recent_insights(symbol, limit)
    return {"insights": insights}


# ==================== 回测 ====================

@app.get("/api/backtest/strategies")
async def get_backtest_strategies():
    """获取可用的回测策略列表"""
    return {"strategies": list_strategies()}


@app.post("/api/backtest/run")
async def run_backtest(request: dict):
    """
    执行回测
    请求: {
        strategy_name: "ma_cross",       # 策略名称
        symbol: "BTCUSDT",               # 交易对
        timeframe: "1h",                 # 时间周期
        days: 90,                         # 回测天数
        start_date: "2026-01-01",        # 开始日期 (可选)
        end_date: "2026-08-01",          # 结束日期 (可选)
        initial_capital: 10000,           # 初始资金
        params: {...}                     # 策略参数 (可选)
    }
    """
    strategy_name = request.get("strategy_name", "ma_cross")
    symbol = request.get("symbol", "BTCUSDT")
    timeframe = request.get("timeframe", "1h")
    days = request.get("days", 90)
    start_date = request.get("start_date")
    end_date = request.get("end_date")
    initial_capital = request.get("initial_capital", 10000)
    custom_params = request.get("params", {})

    # 获取策略
    strategy_info = get_strategy(strategy_name)
    if not strategy_info:
        return {"error": f"Unknown strategy: {strategy_name}"}

    strategy_fn = strategy_info['fn']
    params = {**strategy_info['default_params'], **custom_params}

    try:
        # 获取历史数据
        df = await fetch_klines(
            symbol=symbol,
            interval=timeframe,
            start_date=start_date,
            end_date=end_date,
            days=days,
        )

        # 添加技术指标
        df = add_indicators(df)

        # 执行回测
        engine = BacktestEngine(BacktestConfig(initial_capital=initial_capital))
        result = engine.run(
            df=df,
            strategy_fn=strategy_fn,
            strategy_params=params,
            strategy_name=strategy_info['name'],
            symbol=symbol,
            timeframe=timeframe,
        )

        return result.to_dict()

    except Exception as e:
        logger.error(f"Backtest failed: {e}")
        return {"error": str(e)}


@app.post("/api/backtest/optimize")
async def optimize_backtest(request: dict):
    """
    参数优化
    请求: {
        strategy_name: "ma_cross",
        symbol: "BTCUSDT",
        timeframe: "1h",
        days: 90,
        method: "grid",               # grid / random / genetic
        param_grid: {                  # grid search 参数
            "fast_period": [3, 5, 8],
            "slow_period": [15, 20, 30]
        },
        metric: "sharpe_ratio"         # 优化目标
    }
    """
    strategy_name = request.get("strategy_name", "ma_cross")
    symbol = request.get("symbol", "BTCUSDT")
    timeframe = request.get("timeframe", "1h")
    days = request.get("days", 90)
    method = request.get("method", "grid")
    param_grid = request.get("param_grid", {})
    metric = request.get("metric", "sharpe_ratio")

    strategy_info = get_strategy(strategy_name)
    if not strategy_info:
        return {"error": f"Unknown strategy: {strategy_name}"}

    try:
        df = await fetch_klines(symbol=symbol, interval=timeframe, days=days)
        df = add_indicators(df)

        optimizer = ParameterOptimizer()

        if method == "grid":
            result = optimizer.grid_search(
                df=df,
                strategy_fn=strategy_info['fn'],
                param_grid=param_grid or strategy_info['default_params'],
                metric=metric,
                strategy_name=strategy_info['name'],
                symbol=symbol,
                timeframe=timeframe,
            )
        elif method == "random":
            result = optimizer.random_search(
                df=df,
                strategy_fn=strategy_info['fn'],
                param_ranges=param_grid,
                n_trials=request.get('n_trials', 50),
                metric=metric,
                strategy_name=strategy_info['name'],
                symbol=symbol,
                timeframe=timeframe,
            )
        elif method == "genetic":
            ga = GeneticOptimizer()
            result = ga.optimize(
                df=df,
                strategy_fn=strategy_info['fn'],
                param_ranges=param_grid,
                metric=metric,
                strategy_name=strategy_info['name'],
                symbol=symbol,
                timeframe=timeframe,
            )
        else:
            return {"error": f"Unknown method: {method}"}

        return result

    except Exception as e:
        logger.error(f"Optimization failed: {e}")
        return {"error": str(e)}


@app.post("/api/backtest/walk-forward")
async def walk_forward_analysis(request: dict):
    """
    Walk-Forward 分析 (防过拟合)
    请求: {
        strategy_name: "ma_cross",
        symbol: "BTCUSDT",
        timeframe: "1h",
        days: 180,
        n_splits: 5,
        param_grid: {...}
    }
    """
    strategy_name = request.get("strategy_name", "ma_cross")
    symbol = request.get("symbol", "BTCUSDT")
    timeframe = request.get("timeframe", "1h")
    days = request.get("days", 180)
    n_splits = request.get("n_splits", 5)
    param_grid = request.get("param_grid", {})

    strategy_info = get_strategy(strategy_name)
    if not strategy_info:
        return {"error": f"Unknown strategy: {strategy_name}"}

    try:
        df = await fetch_klines(symbol=symbol, interval=timeframe, days=days)
        df = add_indicators(df)

        optimizer = ParameterOptimizer()
        result = optimizer.walk_forward(
            df=df,
            strategy_fn=strategy_info['fn'],
            param_grid=param_grid or strategy_info['default_params'],
            n_splits=n_splits,
            strategy_name=strategy_info['name'],
            symbol=symbol,
            timeframe=timeframe,
        )

        return result

    except Exception as e:
        logger.error(f"Walk-forward failed: {e}")
        return {"error": str(e)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
