"""
统一交易所抽象层
学习自 Blankly + NexusQuant 的设计模式
支持: 币安、MT4/5、Gate.io、OKX 等
"""

import abc
import time
from dataclasses import dataclass
from enum import Enum
from typing import Optional, List, Dict, Callable
from datetime import datetime


class OrderSide(Enum):
    BUY = "buy"
    SELL = "sell"


class OrderType(Enum):
    MARKET = "market"
    LIMIT = "limit"
    STOP = "stop"
    STOP_LIMIT = "stop_limit"


class OrderStatus(Enum):
    PENDING = "pending"
    FILLED = "filled"
    PARTIALLY_FILLED = "partially_filled"
    CANCELLED = "cancelled"
    REJECTED = "rejected"


@dataclass
class Ticker:
    symbol: str
    price: float
    bid: float
    ask: float
    volume_24h: float
    change_24h: float
    high_24h: float
    low_24h: float
    timestamp: float


@dataclass
class Kline:
    timestamp: float
    open: float
    high: float
    low: float
    close: float
    volume: float


@dataclass
class Order:
    id: str
    symbol: str
    side: OrderSide
    type: OrderType
    quantity: float
    price: float
    status: OrderStatus
    filled_quantity: float
    average_price: float
    fee: float
    created_at: datetime
    updated_at: datetime


@dataclass
class Position:
    symbol: str
    side: OrderSide
    quantity: float
    entry_price: float
    mark_price: float
    unrealized_pnl: float
    leverage: int
    liquidation_price: float


@dataclass
class Account:
    total_balance: float
    available_balance: float
    unrealized_pnl: float
    margin_used: float
    positions: List[Position]


# ==================== 缓存装饰器 ====================

class CacheManager:
    """API 调用缓存 (学习自 NexusQuant)"""

    def __init__(self, default_ttl: float = 5.0):
        self._cache: Dict[str, tuple] = {}
        self._default_ttl = default_ttl

    def get(self, key: str) -> Optional[any]:
        if key in self._cache:
            value, expire_time = self._cache[key]
            if time.time() < expire_time:
                return value
            del self._cache[key]
        return None

    def set(self, key: str, value: any, ttl: float = None):
        self._cache[key] = (value, time.time() + (ttl or self._default_ttl))

    def cached(self, ttl: float = None):
        """装饰器: 自动缓存函数结果"""
        def decorator(func):
            def wrapper(*args, **kwargs):
                cache_key = f"{func.__name__}:{args}:{kwargs}"
                result = self.get(cache_key)
                if result is not None:
                    return result
                result = func(*args, **kwargs)
                self.set(cache_key, result, ttl)
                return result
            return wrapper
        return decorator


# ==================== 限频管理器 ====================

class RateLimitManager:
    """API 限频管理 (学习自 NexusQuant)"""

    def __init__(self):
        self._call_times: Dict[str, List[float]] = {}

    def check_rate_limit(self, endpoint: str, max_calls: int, window: float) -> bool:
        now = time.time()
        if endpoint not in self._call_times:
            self._call_times[endpoint] = []

        # 清理过期记录
        self._call_times[endpoint] = [
            t for t in self._call_times[endpoint] if now - t < window
        ]

        if len(self._call_times[endpoint]) >= max_calls:
            return False  # 超频

        self._call_times[endpoint].append(now)
        return True

    def wait_if_needed(self, endpoint: str, max_calls: int, window: float):
        while not self.check_rate_limit(endpoint, max_calls, window):
            time.sleep(0.1)


# ==================== 交易所抽象基类 ====================

class ExchangeInterface(abc.ABC):
    """
    统一交易所接口 (学习自 Blankly ABCExchange + NexusQuant IExchangeClient)
    所有交易所适配器必须实现这些方法
    """

    def __init__(self, config: dict):
        self.config = config
        self.cache = CacheManager()
        self.rate_limiter = RateLimitManager()
        self._connected = False

    # ==================== 连接管理 ====================

    @abc.abstractmethod
    async def connect(self) -> bool:
        """连接交易所"""
        pass

    @abc.abstractmethod
    async def disconnect(self):
        """断开连接"""
        pass

    @property
    def is_connected(self) -> bool:
        return self._connected

    # ==================== 行情数据 ====================

    @abc.abstractmethod
    async def get_ticker(self, symbol: str) -> Ticker:
        """获取最新价格"""
        pass

    @abc.abstractmethod
    async def get_klines(
        self, symbol: str, interval: str, limit: int = 100,
        start_time: Optional[float] = None, end_time: Optional[float] = None
    ) -> List[Kline]:
        """获取 K 线数据"""
        pass

    @abc.abstractmethod
    async def subscribe_ticker(self, symbol: str, callback: Callable):
        """订阅实时行情"""
        pass

    @abc.abstractmethod
    async def subscribe_kline(self, symbol: str, interval: str, callback: Callable):
        """订阅实时 K 线"""
        pass

    # ==================== 账户信息 ====================

    @abc.abstractmethod
    async def get_account(self) -> Account:
        """获取账户信息"""
        pass

    @abc.abstractmethod
    async def get_balance(self) -> Dict[str, float]:
        """获取余额"""
        pass

    @abc.abstractmethod
    async def get_positions(self) -> List[Position]:
        """获取持仓"""
        pass

    # ==================== 交易操作 ====================

    @abc.abstractmethod
    async def place_order(
        self, symbol: str, side: OrderSide, order_type: OrderType,
        quantity: float, price: Optional[float] = None,
        stop_price: Optional[float] = None,
        take_profit: Optional[float] = None,
        stop_loss: Optional[float] = None,
        **kwargs
    ) -> Order:
        """下单"""
        pass

    @abc.abstractmethod
    async def cancel_order(self, symbol: str, order_id: str) -> bool:
        """撤单"""
        pass

    @abc.abstractmethod
    async def modify_order(
        self, symbol: str, order_id: str,
        price: Optional[float] = None,
        quantity: Optional[float] = None,
        stop_loss: Optional[float] = None,
        take_profit: Optional[float] = None,
    ) -> Order:
        """修改订单"""
        pass

    @abc.abstractmethod
    async def close_position(self, symbol: str) -> Order:
        """平仓"""
        pass

    # ==================== 便捷方法 ====================

    async def market_buy(self, symbol: str, quantity: float, **kwargs) -> Order:
        return await self.place_order(symbol, OrderSide.BUY, OrderType.MARKET, quantity, **kwargs)

    async def market_sell(self, symbol: str, quantity: float, **kwargs) -> Order:
        return await self.place_order(symbol, OrderSide.SELL, OrderType.MARKET, quantity, **kwargs)

    async def limit_buy(self, symbol: str, quantity: float, price: float, **kwargs) -> Order:
        return await self.place_order(symbol, OrderSide.BUY, OrderType.LIMIT, quantity, price, **kwargs)

    async def limit_sell(self, symbol: str, quantity: float, price: float, **kwargs) -> Order:
        return await self.place_order(symbol, OrderSide.SELL, OrderType.LIMIT, quantity, price, **kwargs)


# ==================== 交易所工厂 ====================

class ExchangeFactory:
    """
    交易所工厂 (学习自 NexusQuant ExchangeFactory)
    根据配置创建对应的交易所客户端
    """

    _registry: Dict[str, type] = {}

    @classmethod
    def register(cls, name: str, exchange_class: type):
        """注册交易所"""
        cls._registry[name] = exchange_class

    @classmethod
    def create(cls, exchange_name: str, config: dict) -> ExchangeInterface:
        """创建交易所实例"""
        if exchange_name not in cls._registry:
            raise ValueError(f"Unknown exchange: {exchange_name}. Available: {list(cls._registry.keys())}")
        return cls._registry[exchange_name](config)

    @classmethod
    def list_exchanges(cls) -> List[str]:
        return list(cls._registry.keys())
