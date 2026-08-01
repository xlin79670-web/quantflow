"""
回测引擎核心
支持真实历史数据、多种策略、详细报告
"""

import asyncio
import json
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from typing import Callable, Optional

import numpy as np
import pandas as pd
from loguru import logger


class OrderSide(Enum):
    BUY = "buy"
    SELL = "sell"


class PositionSide(Enum):
    LONG = "long"
    SHORT = "short"
    FLAT = "flat"


@dataclass
class Signal:
    """交易信号"""
    action: str           # buy, sell
    price: float
    time: datetime
    reason: str = ""
    quantity_pct: float = 1.0  # 仓位比例 (0-1)
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None


@dataclass
class Trade:
    """已完成的交易"""
    id: int
    entry_time: datetime
    exit_time: datetime
    side: str
    entry_price: float
    exit_price: float
    quantity: float
    pnl: float              # 绝对盈亏
    pnl_pct: float           # 百分比盈亏
    fee: float
    reason_entry: str = ""
    reason_exit: str = ""
    duration: timedelta = field(default_factory=timedelta)

    @property
    def is_win(self) -> bool:
        return self.pnl > 0


@dataclass
class BacktestConfig:
    """回测配置"""
    initial_capital: float = 10000.0
    fee_rate: float = 0.001         # 手续费率 0.1%
    slippage: float = 0.0005        # 滑点 0.05%
    max_position_pct: float = 1.0   # 最大仓位比例
    enable_short: bool = False      # 是否允许做空
    risk_free_rate: float = 0.02    # 无风险利率 (年化)


@dataclass
class BacktestResult:
    """回测结果"""
    # 基础信息
    strategy_name: str
    symbol: str
    timeframe: str
    start_date: str
    end_date: str
    duration_days: int

    # 收益指标
    initial_capital: float
    final_capital: float
    total_return: float           # 总收益率 %
    annual_return: float          # 年化收益率 %
    daily_returns: list           # 每日收益率

    # 风险指标
    max_drawdown: float           # 最大回撤 %
    max_drawdown_duration: int    # 最大回撤持续天数
    volatility: float             # 年化波动率
    sharpe_ratio: float           # 夏普比率
    sortino_ratio: float          # 索提诺比率
    calmar_ratio: float           # 卡玛比率

    # 交易指标
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: float               # 胜率 %
    profit_factor: float          # 盈亏比
    avg_win: float                # 平均盈利 %
    avg_loss: float               # 平均亏损 %
    max_win: float                # 最大单笔盈利 %
    max_loss: float               # 最大单笔亏损 %
    avg_trade_duration: float     # 平均持仓时间 (小时)
    max_consecutive_wins: int     # 最大连胜
    max_consecutive_losses: int   # 最大连亏

    # 权益曲线
    equity_curve: list            # [(date, equity), ...]
    drawdown_curve: list          # [(date, drawdown), ...]
    trades: list                  # 交易记录

    def to_dict(self) -> dict:
        return {
            "strategy_name": self.strategy_name,
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "start_date": self.start_date,
            "end_date": self.end_date,
            "duration_days": self.duration_days,
            "initial_capital": self.initial_capital,
            "final_capital": round(self.final_capital, 2),
            "total_return": round(self.total_return, 4),
            "annual_return": round(self.annual_return, 4),
            "max_drawdown": round(self.max_drawdown, 4),
            "max_drawdown_duration": self.max_drawdown_duration,
            "volatility": round(self.volatility, 4),
            "sharpe_ratio": round(self.sharpe_ratio, 4),
            "sortino_ratio": round(self.sortino_ratio, 4),
            "calmar_ratio": round(self.calmar_ratio, 4),
            "total_trades": self.total_trades,
            "winning_trades": self.winning_trades,
            "losing_trades": self.losing_trades,
            "win_rate": round(self.win_rate, 2),
            "profit_factor": round(self.profit_factor, 4),
            "avg_win": round(self.avg_win, 4),
            "avg_loss": round(self.avg_loss, 4),
            "max_win": round(self.max_win, 4),
            "max_loss": round(self.max_loss, 4),
            "avg_trade_duration_hours": round(self.avg_trade_duration, 2),
            "max_consecutive_wins": self.max_consecutive_wins,
            "max_consecutive_losses": self.max_consecutive_losses,
            "equity_curve": self.equity_curve,
            "drawdown_curve": self.drawdown_curve,
            "trades": [
                {
                    "id": t.id,
                    "entry_time": t.entry_time.isoformat(),
                    "exit_time": t.exit_time.isoformat(),
                    "side": t.side,
                    "entry_price": round(t.entry_price, 2),
                    "exit_price": round(t.exit_price, 2),
                    "quantity": round(t.quantity, 8),
                    "pnl": round(t.pnl, 2),
                    "pnl_pct": round(t.pnl_pct, 4),
                    "fee": round(t.fee, 4),
                    "reason_entry": t.reason_entry,
                    "reason_exit": t.reason_exit,
                    "duration_hours": round(t.duration.total_seconds() / 3600, 2),
                    "is_win": t.is_win,
                }
                for t in self.trades
            ],
        }

    def summary(self) -> str:
        """生成文字摘要"""
        return f"""
📊 回测报告: {self.strategy_name}
{'='*50}
📅 区间: {self.start_date} ~ {self.end_date} ({self.duration_days} 天)
💰 初始资金: ${self.initial_capital:,.2f}
💰 最终资金: ${self.final_capital:,.2f}
📈 总收益: {self.total_return:+.2f}%
📈 年化收益: {self.annual_return:+.2f}%

📉 最大回撤: {self.max_drawdown:.2f}%
📉 回撤持续: {self.max_drawdown_duration} 天
📊 波动率: {self.volatility:.2f}%
📊 夏普比率: {self.sharpe_ratio:.2f}
📊 索提诺比率: {self.sortino_ratio:.2f}
📊 卡玛比率: {self.calmar_ratio:.2f}

🔢 总交易: {self.total_trades}
✅ 盈利: {self.winning_trades} ({self.win_rate:.1f}%)
❌ 亏损: {self.losing_trades}
📊 盈亏比: {self.profit_factor:.2f}
📈 平均盈利: {self.avg_win:+.2f}%
📉 平均亏损: {self.avg_loss:+.2f}%
🏆 最大盈利: {self.max_win:+.2f}%
💀 最大亏损: {self.max_loss:+.2f}%
⏱️ 平均持仓: {self.avg_trade_duration:.1f} 小时
🔥 最大连胜: {self.max_consecutive_wins}
💔 最大连亏: {self.max_consecutive_losses}
"""


class BacktestEngine:
    """回测引擎"""

    def __init__(self, config: BacktestConfig = None):
        self.config = config or BacktestConfig()

    def run(
        self,
        df: pd.DataFrame,
        strategy_fn: Callable,
        strategy_params: dict,
        strategy_name: str = "Strategy",
        symbol: str = "BTCUSDT",
        timeframe: str = "1h",
    ) -> BacktestResult:
        """
        执行回测
        
        Args:
            df: OHLCV 数据 (columns: open, high, low, close, volume, index 为 datetime)
            strategy_fn: 策略函数 strategy(df, params) -> list[Signal]
            strategy_params: 策略参数
            strategy_name: 策略名称
            symbol: 交易对
            timeframe: 时间周期
        """
        logger.info(f"Starting backtest: {strategy_name} on {symbol} {timeframe}")
        logger.info(f"Data: {len(df)} bars from {df.index[0]} to {df.index[-1]}")

        # 复制数据避免修改原始数据
        df = df.copy()

        # 执行策略获取信号
        signals = strategy_fn(df, strategy_params)
        logger.info(f"Strategy generated {len(signals)} signals")

        # 模拟交易
        trades, equity_curve = self._simulate(signals, df)

        # 计算指标
        result = self._calculate_metrics(
            trades=trades,
            equity_curve=equity_curve,
            strategy_name=strategy_name,
            symbol=symbol,
            timeframe=timeframe,
            df=df,
        )

        logger.info(f"Backtest complete: {result.total_return:+.2f}%, {result.total_trades} trades, Sharpe: {result.sharpe_ratio:.2f}")
        return result

    def _simulate(self, signals: list, df: pd.DataFrame) -> tuple:
        """模拟交易执行"""
        capital = self.config.initial_capital
        position = None  # {side, entry_price, quantity, entry_time, reason}
        trades = []
        equity = []
        trade_id = 0

        # 建立时间索引的信号映射
        signal_map = {}
        for s in signals:
            key = s.time if isinstance(s.time, datetime) else pd.Timestamp(s.time)
            signal_map[key] = s

        for i, (idx, row) in enumerate(df.iterrows()):
            current_time = idx if isinstance(idx, datetime) else pd.Timestamp(idx)
            current_price = row['close']
            current_low = row['low']
            current_high = row['high']

            # 检查止损止盈
            if position is not None:
                exit_signal = self._check_exit(position, current_low, current_high, current_time)
                if exit_signal:
                    trade = self._execute_exit(position, exit_signal, trade_id)
                    trades.append(trade)
                    capital += trade.pnl + position['quantity'] * position['entry_price']
                    position = None
                    trade_id += 1

            # 处理信号
            if current_time in signal_map:
                signal = signal_map[current_time]

                if signal.action == 'buy' and position is None:
                    # 开多仓
                    entry_price = signal.price * (1 + self.config.slippage)
                    invest = capital * signal.quantity_pct * self.config.max_position_pct
                    quantity = invest / entry_price
                    fee = invest * self.config.fee_rate

                    position = {
                        'side': 'long',
                        'entry_price': entry_price,
                        'quantity': quantity,
                        'entry_time': current_time,
                        'reason': signal.reason,
                        'stop_loss': signal.stop_loss,
                        'take_profit': signal.take_profit,
                    }
                    capital -= (invest + fee)

                elif signal.action == 'sell' and position is not None:
                    # 平仓
                    exit_price = signal.price * (1 - self.config.slippage)
                    trade = self._execute_exit(position, Signal(
                        action='sell',
                        price=exit_price,
                        time=current_time,
                        reason=signal.reason,
                    ), trade_id)
                    trades.append(trade)
                    capital += trade.pnl + position['quantity'] * position['entry_price']
                    position = None
                    trade_id += 1

            # 记录权益
            position_value = 0
            if position:
                position_value = position['quantity'] * current_price
            equity.append((current_time, capital + position_value))

        # 强制平仓未关闭的持仓
        if position:
            last_price = df.iloc[-1]['close']
            trade = self._execute_exit(position, Signal(
                action='sell',
                price=last_price,
                time=df.index[-1],
                reason='回测结束强平',
            ), trade_id)
            trades.append(trade)
            capital += trade.pnl + position['quantity'] * position['entry_price']

        return trades, equity

    def _check_exit(self, position: dict, low: float, high: float, time: datetime) -> Optional[Signal]:
        """检查止损止盈"""
        entry = position['entry_price']

        # 止损
        if position.get('stop_loss'):
            stop_price = entry * (1 - position['stop_loss'])
            if low <= stop_price:
                return Signal(action='sell', price=stop_price, time=time, reason=f"止损 {position['stop_loss']*100}%")

        # 止盈
        if position.get('take_profit'):
            tp_price = entry * (1 + position['take_profit'])
            if high >= tp_price:
                return Signal(action='sell', price=tp_price, time=time, reason=f"止盈 {position['take_profit']*100}%")

        return None

    def _execute_exit(self, position: dict, exit_signal: Signal, trade_id: int) -> Trade:
        """执行平仓"""
        exit_price = exit_signal.price * (1 - self.config.slippage)
        entry_price = position['entry_price']
        quantity = position['quantity']

        gross_pnl = (exit_price - entry_price) * quantity
        fee = exit_price * quantity * self.config.fee_rate
        net_pnl = gross_pnl - fee
        pnl_pct = (exit_price - entry_price) / entry_price * 100

        return Trade(
            id=trade_id,
            entry_time=position['entry_time'],
            exit_time=exit_signal.time,
            side=position['side'],
            entry_price=entry_price,
            exit_price=exit_price,
            quantity=quantity,
            pnl=net_pnl,
            pnl_pct=pnl_pct,
            fee=fee,
            reason_entry=position.get('reason', ''),
            reason_exit=exit_signal.reason,
            duration=exit_signal.time - position['entry_time'],
        )

    def _calculate_metrics(
        self,
        trades: list,
        equity_curve: list,
        strategy_name: str,
        symbol: str,
        timeframe: str,
        df: pd.DataFrame,
    ) -> BacktestResult:
        """计算回测指标"""
        # 权益序列
        equity_values = [e[1] for e in equity_curve]
        equity_dates = [e[0] for e in equity_curve]

        initial = self.config.initial_capital
        final = equity_values[-1] if equity_values else initial

        # 日收益率
        equity_series = pd.Series(equity_values, index=equity_dates)
        daily_equity = equity_series.resample('D').last().dropna()
        daily_returns = daily_equity.pct_change().dropna().tolist()

        # 总收益
        total_return = (final - initial) / initial * 100

        # 年化收益
        days = (equity_dates[-1] - equity_dates[0]).days if len(equity_dates) > 1 else 1
        annual_return = ((final / initial) ** (365 / max(days, 1)) - 1) * 100

        # 最大回撤
        peak = equity_series.expanding().max()
        drawdown = (equity_series - peak) / peak
        max_drawdown = abs(drawdown.min()) * 100

        # 最大回撤持续时间
        dd_start = None
        max_dd_duration = 0
        current_dd_duration = 0
        for i, (idx, dd) in enumerate(drawdown.items()):
            if dd < 0:
                current_dd_duration += 1
                max_dd_duration = max(max_dd_duration, current_dd_duration)
            else:
                current_dd_duration = 0

        # 波动率
        if daily_returns:
            volatility = np.std(daily_returns) * np.sqrt(365) * 100
        else:
            volatility = 0

        # 夏普比率
        if daily_returns and np.std(daily_returns) > 0:
            excess_return = np.mean(daily_returns) - self.config.risk_free_rate / 365
            sharpe_ratio = excess_return / np.std(daily_returns) * np.sqrt(365)
        else:
            sharpe_ratio = 0

        # 索提诺比率
        downside_returns = [r for r in daily_returns if r < 0]
        if downside_returns and np.std(downside_returns) > 0:
            sortino_ratio = (np.mean(daily_returns) - self.config.risk_free_rate / 365) / np.std(downside_returns) * np.sqrt(365)
        else:
            sortino_ratio = 0

        # 卡玛比率
        calmar_ratio = annual_return / max_drawdown if max_drawdown > 0 else 0

        # 交易统计
        total_trades = len(trades)
        winning = [t for t in trades if t.is_win]
        losing = [t for t in trades if not t.is_win]

        win_rate = len(winning) / total_trades * 100 if total_trades > 0 else 0
        avg_win = np.mean([t.pnl_pct for t in winning]) if winning else 0
        avg_loss = np.mean([t.pnl_pct for t in losing]) if losing else 0
        max_win = max([t.pnl_pct for t in trades]) if trades else 0
        max_loss = min([t.pnl_pct for t in trades]) if trades else 0

        # 盈亏比
        total_profit = sum(t.pnl for t in winning)
        total_loss = abs(sum(t.pnl for t in losing))
        profit_factor = total_profit / total_loss if total_loss > 0 else float('inf')

        # 平均持仓时间
        if trades:
            avg_duration = np.mean([t.duration.total_seconds() / 3600 for t in trades])
        else:
            avg_duration = 0

        # 最大连胜/连亏
        max_consecutive_wins = 0
        max_consecutive_losses = 0
        current_wins = 0
        current_losses = 0
        for t in trades:
            if t.is_win:
                current_wins += 1
                current_losses = 0
                max_consecutive_wins = max(max_consecutive_wins, current_wins)
            else:
                current_losses += 1
                current_wins = 0
                max_consecutive_losses = max(max_consecutive_losses, current_losses)

        # 回撤曲线 (采样)
        drawdown_curve = [(str(idx), round(dd * 100, 4)) for idx, dd in list(drawdown.items())[::max(1, len(drawdown)//100)]]
        equity_curve_sampled = [(str(idx), round(eq, 2)) for idx, eq in list(zip(equity_dates, equity_values))[::max(1, len(equity_values)//100)]]

        return BacktestResult(
            strategy_name=strategy_name,
            symbol=symbol,
            timeframe=timeframe,
            start_date=str(equity_dates[0].date()) if equity_dates else "",
            end_date=str(equity_dates[-1].date()) if equity_dates else "",
            duration_days=days,
            initial_capital=initial,
            final_capital=final,
            total_return=total_return,
            annual_return=annual_return,
            daily_returns=daily_returns,
            max_drawdown=max_drawdown,
            max_drawdown_duration=max_dd_duration,
            volatility=volatility,
            sharpe_ratio=sharpe_ratio,
            sortino_ratio=sortino_ratio,
            calmar_ratio=calmar_ratio,
            total_trades=total_trades,
            winning_trades=len(winning),
            losing_trades=len(losing),
            win_rate=win_rate,
            profit_factor=profit_factor,
            avg_win=avg_win,
            avg_loss=avg_loss,
            max_win=max_win,
            max_loss=max_loss,
            avg_trade_duration=avg_duration,
            max_consecutive_wins=max_consecutive_wins,
            max_consecutive_losses=max_consecutive_losses,
            equity_curve=equity_curve_sampled,
            drawdown_curve=drawdown_curve,
            trades=trades,
        )
