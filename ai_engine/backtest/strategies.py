"""
内置回测策略
每个策略函数签名: strategy(df, params) -> list[Signal]
"""

import pandas as pd
import numpy as np
from datetime import datetime
from typing import List

from .engine import Signal


# ==================== 1. 均线交叉策略 ====================

def ma_cross(df: pd.DataFrame, params: dict) -> List[Signal]:
    """
    均线交叉策略
    金叉买入，死叉卖出
    
    参数:
        fast_period: 快线周期 (默认 5)
        slow_period: 慢线周期 (默认 20)
        stop_loss: 止损比例 (默认 0.03 = 3%)
        take_profit: 止盈比例 (默认 0.06 = 6%)
    """
    fast = params.get('fast_period', 5)
    slow = params.get('slow_period', 20)
    stop_loss = params.get('stop_loss', 0.03)
    take_profit = params.get('take_profit', 0.06)

    df = df.copy()
    df['ma_fast'] = df['close'].rolling(fast).mean()
    df['ma_slow'] = df['close'].rolling(slow).mean()

    signals = []
    position = None

    for i in range(slow, len(df)):
        price = df['close'].iloc[i]
        ma_f = df['ma_fast'].iloc[i]
        ma_s = df['ma_slow'].iloc[i]
        ma_f_prev = df['ma_fast'].iloc[i-1]
        ma_s_prev = df['ma_slow'].iloc[i-1]

        # 金叉: 快线上穿慢线
        if ma_f > ma_s and ma_f_prev <= ma_s_prev and position is None:
            signals.append(Signal(
                action='buy',
                price=price,
                time=df.index[i],
                reason=f"MA{fast} 上穿 MA{slow} (金叉)",
                stop_loss=stop_loss,
                take_profit=take_profit,
            ))
            position = {'entry': price}

        # 死叉: 快线下穿慢线
        elif ma_f < ma_s and ma_f_prev >= ma_s_prev and position is not None:
            signals.append(Signal(
                action='sell',
                price=price,
                time=df.index[i],
                reason=f"MA{fast} 下穿 MA{slow} (死叉)",
            ))
            position = None

    return signals


# ==================== 2. RSI 超买超卖策略 ====================

def rsi_reversal(df: pd.DataFrame, params: dict) -> List[Signal]:
    """
    RSI 反转策略
    RSI < 超卖线买入，RSI > 超买线卖出
    
    参数:
        rsi_period: RSI 周期 (默认 14)
        oversold: 超卖阈值 (默认 30)
        overbought: 超买阈值 (默认 70)
        stop_loss: 止损比例 (默认 0.03)
        take_profit: 止盈比例 (默认 0.06)
    """
    period = params.get('rsi_period', 14)
    oversold = params.get('oversold', 30)
    overbought = params.get('overbought', 70)
    stop_loss = params.get('stop_loss', 0.03)
    take_profit = params.get('take_profit', 0.06)

    df = df.copy()

    # 计算 RSI
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(period).mean()
    rs = gain / loss
    df['rsi'] = 100 - (100 / (1 + rs))

    signals = []
    position = None

    for i in range(period, len(df)):
        rsi = df['rsi'].iloc[i]
        price = df['close'].iloc[i]

        # 超卖买入
        if rsi < oversold and position is None:
            signals.append(Signal(
                action='buy',
                price=price,
                time=df.index[i],
                reason=f"RSI={rsi:.1f} < {oversold} (超卖)",
                stop_loss=stop_loss,
                take_profit=take_profit,
            ))
            position = {'entry': price}

        # 超买卖出
        elif rsi > overbought and position is not None:
            signals.append(Signal(
                action='sell',
                price=price,
                time=df.index[i],
                reason=f"RSI={rsi:.1f} > {overbought} (超买)",
            ))
            position = None

    return signals


# ==================== 3. 布林带策略 ====================

def bollinger_bounce(df: pd.DataFrame, params: dict) -> List[Signal]:
    """
    布林带回归策略
    触及下轨买入，触及上轨卖出
    
    参数:
        period: 布林带周期 (默认 20)
        std_dev: 标准差倍数 (默认 2.0)
        stop_loss: 止损比例 (默认 0.03)
        take_profit: 止盈比例 (默认 0.05)
    """
    period = params.get('period', 20)
    std_mult = params.get('std_dev', 2.0)
    stop_loss = params.get('stop_loss', 0.03)
    take_profit = params.get('take_profit', 0.05)

    df = df.copy()
    df['bb_mid'] = df['close'].rolling(period).mean()
    bb_std = df['close'].rolling(period).std()
    df['bb_upper'] = df['bb_mid'] + std_mult * bb_std
    df['bb_lower'] = df['bb_mid'] - std_mult * bb_std

    signals = []
    position = None

    for i in range(period, len(df)):
        price = df['close'].iloc[i]
        lower = df['bb_lower'].iloc[i]
        upper = df['bb_upper'].iloc[i]
        mid = df['bb_mid'].iloc[i]

        # 触及下轨买入
        if price <= lower and position is None:
            signals.append(Signal(
                action='buy',
                price=price,
                time=df.index[i],
                reason=f"价格触及布林带下轨 ({lower:.2f})",
                stop_loss=stop_loss,
                take_profit=take_profit,
            ))
            position = {'entry': price}

        # 触及上轨或中轨卖出
        elif price >= upper and position is not None:
            signals.append(Signal(
                action='sell',
                price=price,
                time=df.index[i],
                reason=f"价格触及布林带上轨 ({upper:.2f})",
            ))
            position = None

    return signals


# ==================== 4. MACD 趋势策略 ====================

def macd_trend(df: pd.DataFrame, params: dict) -> List[Signal]:
    """
    MACD 趋势策略
    MACD 金叉 + 柱状图转正买入，死叉卖出
    
    参数:
        fast: 快线周期 (默认 12)
        slow: 慢线周期 (默认 26)
        signal: 信号线周期 (默认 9)
        stop_loss: 止损比例 (默认 0.04)
        take_profit: 止盈比例 (默认 0.08)
    """
    fast = params.get('fast', 12)
    slow = params.get('slow', 26)
    signal_period = params.get('signal', 9)
    stop_loss = params.get('stop_loss', 0.04)
    take_profit = params.get('take_profit', 0.08)

    df = df.copy()
    ema_fast = df['close'].ewm(span=fast, adjust=False).mean()
    ema_slow = df['close'].ewm(span=slow, adjust=False).mean()
    df['macd'] = ema_fast - ema_slow
    df['macd_signal'] = df['macd'].ewm(span=signal_period, adjust=False).mean()
    df['macd_hist'] = df['macd'] - df['macd_signal']

    signals = []
    position = None

    for i in range(slow + signal_period, len(df)):
        price = df['close'].iloc[i]
        macd = df['macd'].iloc[i]
        macd_sig = df['macd_signal'].iloc[i]
        hist = df['macd_hist'].iloc[i]
        hist_prev = df['macd_hist'].iloc[i-1]

        # MACD 金叉 + 柱状图转正
        if macd > macd_sig and hist > 0 and hist_prev <= 0 and position is None:
            signals.append(Signal(
                action='buy',
                price=price,
                time=df.index[i],
                reason=f"MACD 金叉，柱状图转正 ({hist:.2f})",
                stop_loss=stop_loss,
                take_profit=take_profit,
            ))
            position = {'entry': price}

        # MACD 死叉
        elif macd < macd_sig and hist < 0 and hist_prev >= 0 and position is not None:
            signals.append(Signal(
                action='sell',
                price=price,
                time=df.index[i],
                reason=f"MACD 死叉，柱状图转负 ({hist:.2f})",
            ))
            position = None

    return signals


# ==================== 5. 网格交易策略 ====================

def grid_trading(df: pd.DataFrame, params: dict) -> List[Signal]:
    """
    网格交易策略
    在价格区间内等距挂单
    
    参数:
        grid_count: 网格数量 (默认 10)
        price_range_pct: 价格区间百分比 (默认 0.15 = 15%)
        stop_loss: 止损比例 (默认 0.05)
    """
    grid_count = params.get('grid_count', 10)
    range_pct = params.get('price_range_pct', 0.15)
    stop_loss = params.get('stop_loss', 0.05)

    # 以第一根 K 线的价格为基准
    base_price = df['close'].iloc[0]
    upper = base_price * (1 + range_pct)
    lower = base_price * (1 - range_pct)
    step = (upper - lower) / grid_count

    grid_levels = [lower + i * step for i in range(grid_count + 1)]

    signals = []
    bought_levels = set()

    for i in range(len(df)):
        price = df['close'].iloc[i]

        for level_idx, grid_price in enumerate(grid_levels):
            # 价格下穿网格线 - 买入
            if price <= grid_price and level_idx not in bought_levels:
                if level_idx == 0 or (level_idx - 1) in bought_levels or i < grid_count:
                    signals.append(Signal(
                        action='buy',
                        price=grid_price,
                        time=df.index[i],
                        quantity_pct=1.0 / grid_count,
                        reason=f"网格买入 Level {level_idx} @ {grid_price:.2f}",
                    ))
                    bought_levels.add(level_idx)

            # 价格上穿上一格 - 卖出
            elif level_idx in bought_levels and level_idx < len(grid_levels) - 1:
                if price >= grid_levels[level_idx + 1]:
                    signals.append(Signal(
                        action='sell',
                        price=grid_levels[level_idx + 1],
                        time=df.index[i],
                        quantity_pct=1.0 / grid_count,
                        reason=f"网格卖出 Level {level_idx}",
                    ))
                    bought_levels.discard(level_idx)

    return signals


# ==================== 6. 双 RSI + 成交量策略 ====================

def rsi_volume(df: pd.DataFrame, params: dict) -> List[Signal]:
    """
    RSI + 成交量确认策略
    RSI 超卖 + 成交量放大时买入
    
    参数:
        rsi_period: RSI 周期 (默认 14)
        oversold: 超卖阈值 (默认 30)
        overbought: 超买阈值 (默认 70)
        volume_mult: 成交量放大倍数 (默认 1.5)
        stop_loss: 止损 (默认 0.03)
        take_profit: 止盈 (默认 0.06)
    """
    period = params.get('rsi_period', 14)
    oversold = params.get('oversold', 30)
    overbought = params.get('overbought', 70)
    volume_mult = params.get('volume_mult', 1.5)
    stop_loss = params.get('stop_loss', 0.03)
    take_profit = params.get('take_profit', 0.06)

    df = df.copy()

    # RSI
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(period).mean()
    rs = gain / loss
    df['rsi'] = 100 - (100 / (1 + rs))

    # 成交量 MA
    df['vol_ma'] = df['volume'].rolling(20).mean()

    signals = []
    position = None

    for i in range(max(period, 20), len(df)):
        rsi = df['rsi'].iloc[i]
        price = df['close'].iloc[i]
        vol = df['volume'].iloc[i]
        vol_ma = df['vol_ma'].iloc[i]

        # RSI 超卖 + 成交量放大
        if rsi < oversold and vol > vol_ma * volume_mult and position is None:
            signals.append(Signal(
                action='buy',
                price=price,
                time=df.index[i],
                reason=f"RSI={rsi:.1f} 超卖 + 成交量放大 {vol/vol_ma:.1f}x",
                stop_loss=stop_loss,
                take_profit=take_profit,
            ))
            position = {'entry': price}

        # RSI 超买
        elif rsi > overbought and position is not None:
            signals.append(Signal(
                action='sell',
                price=price,
                time=df.index[i],
                reason=f"RSI={rsi:.1f} 超买",
            ))
            position = None

    return signals


# ==================== 策略注册表 ====================

STRATEGY_REGISTRY = {
    'ma_cross': {
        'name': '均线交叉策略',
        'fn': ma_cross,
        'default_params': {
            'fast_period': 5,
            'slow_period': 20,
            'stop_loss': 0.03,
            'take_profit': 0.06,
        },
        'description': '金叉买入，死叉卖出。适合趋势行情。',
    },
    'rsi_reversal': {
        'name': 'RSI 超买超卖策略',
        'fn': rsi_reversal,
        'default_params': {
            'rsi_period': 14,
            'oversold': 30,
            'overbought': 70,
            'stop_loss': 0.03,
            'take_profit': 0.06,
        },
        'description': 'RSI 超卖买入，超买卖出。适合震荡行情。',
    },
    'bollinger_bounce': {
        'name': '布林带回归策略',
        'fn': bollinger_bounce,
        'default_params': {
            'period': 20,
            'std_dev': 2.0,
            'stop_loss': 0.03,
            'take_profit': 0.05,
        },
        'description': '触及下轨买入，上轨卖出。适合震荡行情。',
    },
    'macd_trend': {
        'name': 'MACD 趋势策略',
        'fn': macd_trend,
        'default_params': {
            'fast': 12,
            'slow': 26,
            'signal': 9,
            'stop_loss': 0.04,
            'take_profit': 0.08,
        },
        'description': 'MACD 金叉买入，死叉卖出。适合趋势行情。',
    },
    'grid_trading': {
        'name': '网格交易策略',
        'fn': grid_trading,
        'default_params': {
            'grid_count': 10,
            'price_range_pct': 0.15,
            'stop_loss': 0.05,
        },
        'description': '在价格区间内等距挂单。适合震荡行情。',
    },
    'rsi_volume': {
        'name': 'RSI + 成交量策略',
        'fn': rsi_volume,
        'default_params': {
            'rsi_period': 14,
            'oversold': 30,
            'overbought': 70,
            'volume_mult': 1.5,
            'stop_loss': 0.03,
            'take_profit': 0.06,
        },
        'description': 'RSI 超卖 + 成交量放大时买入。过滤假信号。',
    },
}


def get_strategy(name: str):
    """获取策略"""
    return STRATEGY_REGISTRY.get(name)


def list_strategies() -> list:
    """列出所有策略"""
    return [
        {
            'key': k,
            'name': v['name'],
            'description': v['description'],
            'default_params': v['default_params'],
        }
        for k, v in STRATEGY_REGISTRY.items()
    ]
