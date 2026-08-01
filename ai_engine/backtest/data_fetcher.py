"""
历史数据获取器
从币安获取真实 K 线数据用于回测
"""

import asyncio
import time
from datetime import datetime, timedelta
from typing import Optional

import httpx
import pandas as pd
from loguru import logger


# 币安 K 线 API
BINANCE_KLINE_URL = "https://api.binance.com/api/v3/klines"

# 时间周期映射
TIMEFRAME_MS = {
    '1m': 60_000,
    '3m': 180_000,
    '5m': 300_000,
    '15m': 900_000,
    '30m': 1_800_000,
    '1h': 3_600_000,
    '2h': 7_200_000,
    '4h': 14_400_000,
    '6h': 21_600_000,
    '8h': 28_800_000,
    '12h': 43_200_000,
    '1d': 86_400_000,
    '3d': 259_200_000,
    '1w': 604_800_000,
}


async def fetch_klines(
    symbol: str = "BTCUSDT",
    interval: str = "1h",
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    days: int = 90,
    limit_per_request: int = 1000,
) -> pd.DataFrame:
    """
    从币安获取历史 K 线数据
    
    Args:
        symbol: 交易对
        interval: K 线周期
        start_date: 开始日期 (YYYY-MM-DD)
        end_date: 结束日期 (YYYY-MM-DD)
        days: 获取最近 N 天数据 (当 start_date 为空时生效)
        limit_per_request: 每次请求的 K 线数量
    
    Returns:
        DataFrame with columns: open, high, low, close, volume
    """
    # 计算时间范围
    if end_date:
        end_ms = int(datetime.strptime(end_date, "%Y-%m-%d").timestamp() * 1000)
    else:
        end_ms = int(time.time() * 1000)

    if start_date:
        start_ms = int(datetime.strptime(start_date, "%Y-%m-%d").timestamp() * 1000)
    else:
        start_ms = end_ms - days * 86_400_000

    logger.info(f"Fetching {symbol} {interval} klines: {datetime.fromtimestamp(start_ms/1000)} to {datetime.fromtimestamp(end_ms/1000)}")

    all_klines = []
    current_start = start_ms
    client = httpx.AsyncClient(timeout=30.0)

    try:
        while current_start < end_ms:
            params = {
                "symbol": symbol,
                "interval": interval,
                "startTime": current_start,
                "endTime": end_ms,
                "limit": limit_per_request,
            }

            try:
                resp = await client.get(BINANCE_KLINE_URL, params=params)
                resp.raise_for_status()
                data = resp.json()
            except Exception as e:
                logger.warning(f"Request failed: {e}, retrying...")
                await asyncio.sleep(1)
                continue

            if not data:
                break

            all_klines.extend(data)

            # 下一批的起始时间 = 最后一根 K 线的 close_time + 1
            last_close_time = data[-1][6]
            current_start = last_close_time + 1

            logger.debug(f"  Fetched {len(data)} klines, total: {len(all_klines)}")

            # 限频保护
            await asyncio.sleep(0.2)

    finally:
        await client.aclose()

    if not all_klines:
        raise ValueError(f"No data fetched for {symbol} {interval}")

    # 转换为 DataFrame
    df = pd.DataFrame(all_klines, columns=[
        'open_time', 'open', 'high', 'low', 'close', 'volume',
        'close_time', 'quote_volume', 'trades', 'taker_buy_base',
        'taker_buy_quote', 'ignore',
    ])

    # 类型转换
    df['open_time'] = pd.to_datetime(df['open_time'], unit='ms')
    for col in ['open', 'high', 'low', 'close', 'volume', 'quote_volume']:
        df[col] = df[col].astype(float)

    # 设置索引
    df.set_index('open_time', inplace=True)
    df = df[['open', 'high', 'low', 'close', 'volume', 'quote_volume']]

    # 去重
    df = df[~df.index.duplicated(keep='first')]
    df.sort_index(inplace=True)

    logger.info(f"Fetched {len(df)} klines for {symbol} {interval}")
    return df


def resample_klines(df: pd.DataFrame, target_interval: str) -> pd.DataFrame:
    """
    重采样 K 线数据 (如 1h -> 4h)
    
    Args:
        df: 原始 K 线数据
        target_interval: 目标周期 (1h, 4h, 1d 等)
    """
    rule_map = {
        '1h': '1h', '2h': '2h', '4h': '4h', '6h': '6h',
        '8h': '8h', '12h': '12h', '1d': '1D', '1w': '1W',
    }

    rule = rule_map.get(target_interval)
    if not rule:
        raise ValueError(f"Unsupported interval: {target_interval}")

    resampled = df.resample(rule).agg({
        'open': 'first',
        'high': 'max',
        'low': 'min',
        'close': 'last',
        'volume': 'sum',
        'quote_volume': 'sum',
    }).dropna()

    return resampled


def add_indicators(df: pd.DataFrame) -> pd.DataFrame:
    """添加常用技术指标"""
    df = df.copy()

    # 移动平均
    for period in [5, 10, 20, 50, 100, 200]:
        df[f'ma_{period}'] = df['close'].rolling(period).mean()

    # EMA
    for period in [12, 26]:
        df[f'ema_{period}'] = df['close'].ewm(span=period, adjust=False).mean()

    # MACD
    df['macd'] = df['ema_12'] - df['ema_26']
    df['macd_signal'] = df['macd'].ewm(span=9, adjust=False).mean()
    df['macd_hist'] = df['macd'] - df['macd_signal']

    # RSI
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
    rs = gain / loss
    df['rsi'] = 100 - (100 / (1 + rs))

    # 布林带
    df['bb_mid'] = df['close'].rolling(20).mean()
    bb_std = df['close'].rolling(20).std()
    df['bb_upper'] = df['bb_mid'] + 2 * bb_std
    df['bb_lower'] = df['bb_mid'] - 2 * bb_std

    # ATR
    high_low = df['high'] - df['low']
    high_close = abs(df['high'] - df['close'].shift())
    low_close = abs(df['low'] - df['close'].shift())
    tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    df['atr'] = tr.rolling(14).mean()

    # 成交量 MA
    df['volume_ma_20'] = df['volume'].rolling(20).mean()

    return df
