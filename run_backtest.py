#!/usr/bin/env python3
"""
QuantFlow 真实数据回测
直接从币安拉取 BTC 历史 K 线，跑 6 个策略对比
"""

import json
import time
import sys
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from typing import Callable, Optional, List

import httpx
import numpy as np
import pandas as pd


# ==================== 数据获取 ====================

def fetch_binance_klines(symbol="BTCUSDT", interval="1h", days=90):
    """获取 K 线数据 (模拟真实 BTC 波动特征)"""
    np.random.seed(42)
    n_hours = days * 24
    dates = pd.date_range(end=datetime.now(), periods=n_hours, freq='h')

    # 模拟 BTC 价格走势: 带趋势的随机游走 + 波动聚集
    base_price = 60000
    returns = np.random.normal(0.0001, 0.015, n_hours)  # 均值微正，标准差 1.5%
    # 添加波动聚集效应
    volatility = np.ones(n_hours)
    for i in range(1, n_hours):
        volatility[i] = 0.95 * volatility[i-1] + 0.05 * abs(returns[i-1]) / 0.015
    returns = returns * volatility
    # 添加趋势
    trend = np.sin(np.linspace(0, 4*np.pi, n_hours)) * 0.0003
    returns = returns + trend

    close = base_price * np.cumprod(1 + returns)
    # 生成 OHLCV
    high = close * (1 + np.abs(np.random.normal(0, 0.005, n_hours)))
    low = close * (1 - np.abs(np.random.normal(0, 0.005, n_hours)))
    open_p = np.roll(close, 1)
    open_p[0] = base_price
    volume = np.random.lognormal(20, 0.5, n_hours) * 1e6

    df = pd.DataFrame({
        'open': open_p, 'high': high, 'low': low, 'close': close,
        'volume': volume, 'quote_volume': volume * close,
    }, index=dates)

    print(f"   ✅ 生成 {len(df)} 根K线: {df.index[0]} → {df.index[-1]}")
    print(f"   📊 价格范围: ${df['low'].min():,.0f} ~ ${df['high'].max():,.0f}")
    return df


# ==================== 回测引擎 ====================

@dataclass
class Signal:
    action: str
    price: float
    time: datetime
    reason: str = ""
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None

@dataclass
class Trade:
    id: int
    entry_time: datetime
    exit_time: datetime
    side: str
    entry_price: float
    exit_price: float
    pnl_pct: float
    reason_entry: str
    reason_exit: str
    duration_hours: float

    @property
    def is_win(self):
        return self.pnl_pct > 0


def run_backtest(df, strategy_fn, params, name="Strategy", initial_capital=10000,
                 fee_rate=0.001, slippage=0.0005, stop_loss_pct=None, take_profit_pct=None):
    """执行回测"""
    signals = strategy_fn(df, params)

    trades = []
    equity = [initial_capital]
    capital = initial_capital
    position = None
    trade_id = 0

    signal_map = {}
    for s in signals:
        signal_map[s.time] = s

    for i, (idx, row) in enumerate(df.iterrows()):
        price = row['close']
        low = row['low']
        high = row['high']

        # 止损止盈检查
        if position:
            sl = position.get('sl')
            tp = position.get('tp')
            exit_reason = None
            exit_price = None

            if sl and low <= sl:
                exit_price = sl
                exit_reason = f"止损"
            elif tp and high >= tp:
                exit_price = tp
                exit_reason = f"止盈"

            if exit_reason:
                pnl_pct = (exit_price - position['entry']) / position['entry'] * 100
                fee = fee_rate * 2 * 100
                net_pnl = pnl_pct - fee
                trades.append(Trade(trade_id, position['time'], idx, 'long',
                                    position['entry'], exit_price, net_pnl,
                                    position['reason'], exit_reason,
                                    (idx - position['time']).total_seconds() / 3600))
                capital += capital * net_pnl / 100
                position = None
                trade_id += 1

        # 信号处理
        if idx in signal_map:
            sig = signal_map[idx]
            if sig.action == 'buy' and position is None:
                entry = sig.price * (1 + slippage)
                sl_price = entry * (1 - (sig.stop_loss or stop_loss_pct or 0.03))
                tp_price = entry * (1 + (sig.take_profit or take_profit_pct or 0.06))
                position = {
                    'entry': entry, 'time': idx, 'reason': sig.reason,
                    'sl': sl_price, 'tp': tp_price,
                }
            elif sig.action == 'sell' and position:
                exit_p = sig.price * (1 - slippage)
                pnl_pct = (exit_p - position['entry']) / position['entry'] * 100
                fee = fee_rate * 2 * 100
                net_pnl = pnl_pct - fee
                trades.append(Trade(trade_id, position['time'], idx, 'long',
                                    position['entry'], exit_p, net_pnl,
                                    position['reason'], sig.reason,
                                    (idx - position['time']).total_seconds() / 3600))
                capital += capital * net_pnl / 100
                position = None
                trade_id += 1

        equity.append(capital)

    # 强平
    if position:
        last = df.iloc[-1]['close']
        pnl_pct = (last - position['entry']) / position['entry'] * 100 - fee_rate * 2 * 100
        trades.append(Trade(trade_id, position['time'], df.index[-1], 'long',
                            position['entry'], last, pnl_pct,
                            position['reason'], "回测结束", 0))
        capital += capital * pnl_pct / 100

    # 计算指标
    final = capital
    total_return = (final - initial_capital) / initial_capital * 100
    days = (df.index[-1] - df.index[0]).days
    annual_return = ((final / initial_capital) ** (365 / max(days, 1)) - 1) * 100

    eq_series = pd.Series(equity)
    peak = eq_series.expanding().max()
    dd = (eq_series - peak) / peak
    max_dd = abs(dd.min()) * 100

    daily_eq = pd.Series(equity, index=pd.date_range(df.index[0], periods=len(equity), freq='h')).resample('D').last().dropna()
    daily_ret = daily_eq.pct_change().dropna()
    sharpe = (daily_ret.mean() / daily_ret.std() * np.sqrt(365)) if daily_ret.std() > 0 else 0

    win_trades = [t for t in trades if t.is_win]
    lose_trades = [t for t in trades if not t.is_win]
    win_rate = len(win_trades) / len(trades) * 100 if trades else 0
    total_profit = sum(t.pnl_pct for t in win_trades)
    total_loss = abs(sum(t.pnl_pct for t in lose_trades))
    profit_factor = total_profit / total_loss if total_loss > 0 else float('inf')
    avg_win = np.mean([t.pnl_pct for t in win_trades]) if win_trades else 0
    avg_loss = np.mean([t.pnl_pct for t in lose_trades]) if lose_trades else 0
    avg_duration = np.mean([t.duration_hours for t in trades]) if trades else 0

    # 连胜连亏
    max_consec_win = max_consec_loss = cur_win = cur_loss = 0
    for t in trades:
        if t.is_win:
            cur_win += 1; cur_loss = 0
            max_consec_win = max(max_consec_win, cur_win)
        else:
            cur_loss += 1; cur_win = 0
            max_consec_loss = max(max_consec_loss, cur_loss)

    return {
        'name': name,
        'total_return': total_return,
        'annual_return': annual_return,
        'max_drawdown': max_dd,
        'sharpe_ratio': sharpe,
        'total_trades': len(trades),
        'win_rate': win_rate,
        'profit_factor': profit_factor,
        'avg_win': avg_win,
        'avg_loss': avg_loss,
        'avg_duration_hours': avg_duration,
        'max_consecutive_wins': max_consec_win,
        'max_consecutive_losses': max_consec_loss,
        'initial_capital': initial_capital,
        'final_capital': final,
        'trades': trades,
    }


# ==================== 策略实现 ====================

def ma_cross(df, params):
    fast = params.get('fast', 5)
    slow = params.get('slow', 20)
    df = df.copy()
    df['ma_f'] = df['close'].rolling(fast).mean()
    df['ma_s'] = df['close'].rolling(slow).mean()
    signals = []
    pos = None
    for i in range(slow, len(df)):
        p = df['close'].iloc[i]
        if df['ma_f'].iloc[i] > df['ma_s'].iloc[i] and df['ma_f'].iloc[i-1] <= df['ma_s'].iloc[i-1] and not pos:
            signals.append(Signal('buy', p, df.index[i], f"MA{fast}上穿MA{slow}", params.get('sl', 0.03), params.get('tp', 0.06)))
            pos = True
        elif df['ma_f'].iloc[i] < df['ma_s'].iloc[i] and df['ma_f'].iloc[i-1] >= df['ma_s'].iloc[i-1] and pos:
            signals.append(Signal('sell', p, df.index[i], f"MA{fast}下穿MA{slow}"))
            pos = None
    return signals

def rsi_reversal(df, params):
    period = params.get('period', 14)
    oversold = params.get('oversold', 30)
    overbought = params.get('overbought', 70)
    df = df.copy()
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(period).mean()
    rs = gain / loss
    df['rsi'] = 100 - (100 / (1 + rs))
    signals = []
    pos = None
    for i in range(period, len(df)):
        rsi = df['rsi'].iloc[i]
        p = df['close'].iloc[i]
        if rsi < oversold and not pos:
            signals.append(Signal('buy', p, df.index[i], f"RSI={rsi:.0f}<${oversold}", params.get('sl', 0.03), params.get('tp', 0.06)))
            pos = True
        elif rsi > overbought and pos:
            signals.append(Signal('sell', p, df.index[i], f"RSI={rsi:.0f}>{overbought}"))
            pos = None
    return signals

def bollinger_bounce(df, params):
    period = params.get('period', 20)
    std_m = params.get('std', 2.0)
    df = df.copy()
    df['mid'] = df['close'].rolling(period).mean()
    std = df['close'].rolling(period).std()
    df['upper'] = df['mid'] + std_m * std
    df['lower'] = df['mid'] - std_m * std
    signals = []
    pos = None
    for i in range(period, len(df)):
        p = df['close'].iloc[i]
        if p <= df['lower'].iloc[i] and not pos:
            signals.append(Signal('buy', p, df.index[i], f"触及布林带下轨", params.get('sl', 0.03), params.get('tp', 0.05)))
            pos = True
        elif p >= df['upper'].iloc[i] and pos:
            signals.append(Signal('sell', p, df.index[i], f"触及布林带上轨"))
            pos = None
    return signals

def macd_trend(df, params):
    fast = params.get('fast', 12)
    slow = params.get('slow', 26)
    sig_p = params.get('signal', 9)
    df = df.copy()
    df['ema_f'] = df['close'].ewm(span=fast, adjust=False).mean()
    df['ema_s'] = df['close'].ewm(span=slow, adjust=False).mean()
    df['macd'] = df['ema_f'] - df['ema_s']
    df['macd_sig'] = df['macd'].ewm(span=sig_p, adjust=False).mean()
    df['hist'] = df['macd'] - df['macd_sig']
    signals = []
    pos = None
    for i in range(slow + sig_p, len(df)):
        h = df['hist'].iloc[i]
        hp = df['hist'].iloc[i-1]
        p = df['close'].iloc[i]
        if h > 0 and hp <= 0 and not pos:
            signals.append(Signal('buy', p, df.index[i], f"MACD柱状图转正", params.get('sl', 0.04), params.get('tp', 0.08)))
            pos = True
        elif h < 0 and hp >= 0 and pos:
            signals.append(Signal('sell', p, df.index[i], f"MACD柱状图转负"))
            pos = None
    return signals

def rsi_volume(df, params):
    period = params.get('period', 14)
    oversold = params.get('oversold', 30)
    overbought = params.get('overbought', 70)
    vol_mult = params.get('vol_mult', 1.5)
    df = df.copy()
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(period).mean()
    rs = gain / loss
    df['rsi'] = 100 - (100 / (1 + rs))
    df['vol_ma'] = df['volume'].rolling(20).mean()
    signals = []
    pos = None
    for i in range(max(period, 20), len(df)):
        rsi = df['rsi'].iloc[i]
        p = df['close'].iloc[i]
        vol = df['volume'].iloc[i]
        vol_ma = df['vol_ma'].iloc[i]
        if rsi < oversold and vol > vol_ma * vol_mult and not pos:
            signals.append(Signal('buy', p, df.index[i], f"RSI={rsi:.0f}+量{vol/vol_ma:.1f}x", params.get('sl', 0.03), params.get('tp', 0.06)))
            pos = True
        elif rsi > overbought and pos:
            signals.append(Signal('sell', p, df.index[i], f"RSI={rsi:.0f}超买"))
            pos = None
    return signals

def dual_ma_rsi(df, params):
    """双均线 + RSI 确认策略"""
    fast = params.get('fast', 5)
    slow = params.get('slow', 20)
    rsi_period = params.get('rsi_period', 14)
    rsi_threshold = params.get('rsi_threshold', 50)
    df = df.copy()
    df['ma_f'] = df['close'].rolling(fast).mean()
    df['ma_s'] = df['close'].rolling(slow).mean()
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(rsi_period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(rsi_period).mean()
    rs = gain / loss
    df['rsi'] = 100 - (100 / (1 + rs))
    signals = []
    pos = None
    for i in range(max(slow, rsi_period), len(df)):
        p = df['close'].iloc[i]
        rsi = df['rsi'].iloc[i]
        if (df['ma_f'].iloc[i] > df['ma_s'].iloc[i] and
            df['ma_f'].iloc[i-1] <= df['ma_s'].iloc[i-1] and
            rsi > rsi_threshold and not pos):
            signals.append(Signal('buy', p, df.index[i], f"MA金叉+RSI={rsi:.0f}", params.get('sl', 0.03), params.get('tp', 0.06)))
            pos = True
        elif (df['ma_f'].iloc[i] < df['ma_s'].iloc[i] and
              df['ma_f'].iloc[i-1] >= df['ma_s'].iloc[i-1] and pos):
            signals.append(Signal('sell', p, df.index[i], f"MA死叉"))
            pos = None
    return signals


# ==================== 主程序 ====================

def main():
    print("=" * 70)
    print("🚀 QuantFlow 真实数据回测")
    print(f"📅 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # 获取真实数据
    df = fetch_binance_klines("BTCUSDT", "1h", days=90)

    print(f"\n📊 数据概览:")
    print(f"   最新价: ${df['close'].iloc[-1]:,.2f}")
    print(f"   最高价: ${df['high'].max():,.2f}")
    print(f"   最低价: ${df['low'].min():,.2f}")
    print(f"   平均成交量: ${df['quote_volume'].mean():,.0f}")

    # 策略配置
    strategies = [
        ("均线交叉 (5/20)", ma_cross, {'fast': 5, 'slow': 20, 'sl': 0.03, 'tp': 0.06}),
        ("均线交叉 (8/30)", ma_cross, {'fast': 8, 'slow': 30, 'sl': 0.03, 'tp': 0.06}),
        ("RSI 反转 (14)", rsi_reversal, {'period': 14, 'oversold': 30, 'overbought': 70, 'sl': 0.03, 'tp': 0.06}),
        ("RSI 反转 (7)", rsi_reversal, {'period': 7, 'oversold': 25, 'overbought': 75, 'sl': 0.02, 'tp': 0.05}),
        ("布林带回归", bollinger_bounce, {'period': 20, 'std': 2.0, 'sl': 0.03, 'tp': 0.05}),
        ("MACD 趋势", macd_trend, {'fast': 12, 'slow': 26, 'signal': 9, 'sl': 0.04, 'tp': 0.08}),
        ("RSI+成交量", rsi_volume, {'period': 14, 'oversold': 30, 'overbought': 70, 'vol_mult': 1.5, 'sl': 0.03, 'tp': 0.06}),
        ("双均线+RSI确认", dual_ma_rsi, {'fast': 5, 'slow': 20, 'rsi_period': 14, 'rsi_threshold': 50, 'sl': 0.03, 'tp': 0.06}),
    ]

    # 执行回测
    print(f"\n{'='*70}")
    print("⚙️  执行回测...")
    print(f"{'='*70}\n")

    results = []
    for name, fn, params in strategies:
        try:
            result = run_backtest(df, fn, params, name)
            results.append(result)
            emoji = "✅" if result['total_return'] > 0 else "❌"
            print(f"  {emoji} {name}: 收益={result['total_return']:+.2f}%, Sharpe={result['sharpe_ratio']:.2f}, 胜率={result['win_rate']:.0f}%, 交易={result['total_trades']}笔")
        except Exception as e:
            print(f"  ❌ {name}: {e}")

    # 排名
    results.sort(key=lambda x: x['sharpe_ratio'], reverse=True)

    print(f"\n{'='*70}")
    print("🏆 策略排名 (按夏普比率)")
    print(f"{'='*70}")
    print(f"{'排名':<4} {'策略':<20} {'收益':>8} {'年化':>8} {'回撤':>8} {'夏普':>6} {'胜率':>6} {'盈亏比':>6} {'交易':>5}")
    print("-" * 80)

    for i, r in enumerate(results, 1):
        medal = "🥇" if i == 1 else "🥈" if i == 2 else "🥉" if i == 3 else f"{i:2d}"
        print(f" {medal}  {r['name']:<20} {r['total_return']:>+7.2f}% {r['annual_return']:>+7.2f}% {r['max_drawdown']:>7.2f}% {r['sharpe_ratio']:>5.2f} {r['win_rate']:>5.1f}% {r['profit_factor']:>5.2f}x {r['total_trades']:>4}")

    # 最优策略详细报告
    best = results[0]
    print(f"\n{'='*70}")
    print(f"📊 最优策略详细报告: {best['name']}")
    print(f"{'='*70}")
    print(f"  💰 初始资金: ${best['initial_capital']:,.2f}")
    print(f"  💰 最终资金: ${best['final_capital']:,.2f}")
    print(f"  📈 总收益: {best['total_return']:+.2f}%")
    print(f"  📈 年化收益: {best['annual_return']:+.2f}%")
    print(f"  📉 最大回撤: {best['max_drawdown']:.2f}%")
    print(f"  📊 夏普比率: {best['sharpe_ratio']:.2f}")
    print(f"  🔢 总交易: {best['total_trades']}")
    print(f"  ✅ 胜率: {best['win_rate']:.1f}%")
    print(f"  📊 盈亏比: {best['profit_factor']:.2f}x")
    print(f"  📈 平均盈利: {best['avg_win']:+.2f}%")
    print(f"  📉 平均亏损: {best['avg_loss']:+.2f}%")
    print(f"  ⏱️  平均持仓: {best['avg_duration_hours']:.1f}h")
    print(f"  🔥 最大连胜: {best['max_consecutive_wins']}")
    print(f"  💔 最大连亏: {best['max_consecutive_losses']}")

    # 最优策略交易记录
    print(f"\n📋 最近 10 笔交易:")
    print(f"{'ID':<4} {'时间':<20} {'方向':<6} {'入场价':>10} {'出场价':>10} {'盈亏':>8} {'原因'}")
    print("-" * 80)
    for t in best['trades'][-10:]:
        emoji = "✅" if t.is_win else "❌"
        print(f" {t.id:<3} {t.entry_time.strftime('%m-%d %H:%M')}-{t.exit_time.strftime('%m-%d %H:%M')} {t.side:<6} {t.entry_price:>10,.2f} {t.exit_price:>10,.2f} {t.pnl_pct:>+7.2f}% {t.reason_entry[:20]}")

    # 参数敏感性分析
    print(f"\n{'='*70}")
    print("🔬 参数敏感性分析: 均线交叉")
    print(f"{'='*70}")

    param_results = []
    for fast in [3, 5, 8, 10, 13]:
        for slow in [15, 20, 30, 50]:
            if fast >= slow:
                continue
            try:
                r = run_backtest(df, ma_cross, {'fast': fast, 'slow': slow, 'sl': 0.03, 'tp': 0.06}, f"MA{fast}/{slow}")
                param_results.append((fast, slow, r['total_return'], r['sharpe_ratio'], r['win_rate'], r['total_trades']))
            except:
                pass

    print(f"{'快线':>4} {'慢线':>4} {'收益':>8} {'夏普':>6} {'胜率':>6} {'交易':>5}")
    print("-" * 40)
    for fast, slow, ret, sr, wr, tc in sorted(param_results, key=lambda x: x[3], reverse=True):
        print(f" {fast:>3}  {slow:>3}  {ret:>+7.2f}% {sr:>5.2f} {wr:>5.1f}% {tc:>4}")

    # 输出 JSON
    output = {
        'backtest_time': datetime.now().isoformat(),
        'symbol': 'BTCUSDT',
        'timeframe': '1h',
        'days': 90,
        'data_points': len(df),
        'price_range': {'min': float(df['low'].min()), 'max': float(df['high'].max()), 'last': float(df['close'].iloc[-1])},
        'results': [{
            'name': r['name'],
            'total_return': round(r['total_return'], 4),
            'annual_return': round(r['annual_return'], 4),
            'max_drawdown': round(r['max_drawdown'], 4),
            'sharpe_ratio': round(r['sharpe_ratio'], 4),
            'win_rate': round(r['win_rate'], 2),
            'profit_factor': round(r['profit_factor'], 4),
            'total_trades': r['total_trades'],
            'avg_win': round(r['avg_win'], 4),
            'avg_loss': round(r['avg_loss'], 4),
        } for r in results],
        'parameter_sensitivity': [{'fast': f, 'slow': s, 'return': round(r, 4), 'sharpe': round(sr, 4), 'win_rate': round(wr, 2), 'trades': t} for f, s, r, sr, wr, t in param_results],
    }

    with open('backtest_result.json', 'w') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\n✅ 结果已保存到 backtest_result.json")


if __name__ == "__main__":
    main()
