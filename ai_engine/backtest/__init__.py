"""回测引擎模块"""

from .engine import BacktestEngine, BacktestConfig, BacktestResult, Signal, Trade
from .data_fetcher import fetch_klines, resample_klines, add_indicators
from .strategies import STRATEGY_REGISTRY, get_strategy, list_strategies
from .optimizer import ParameterOptimizer, GeneticOptimizer

__all__ = [
    'BacktestEngine',
    'BacktestConfig',
    'BacktestResult',
    'Signal',
    'Trade',
    'fetch_klines',
    'resample_klines',
    'add_indicators',
    'STRATEGY_REGISTRY',
    'get_strategy',
    'list_strategies',
    'ParameterOptimizer',
    'GeneticOptimizer',
]
