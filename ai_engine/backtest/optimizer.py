"""
策略参数优化器
贝叶斯优化 + 网格搜索
"""

import itertools
from typing import Callable, Optional

import numpy as np
import pandas as pd
from loguru import logger

from .engine import BacktestEngine, BacktestConfig, BacktestResult


class ParameterOptimizer:
    """策略参数优化器"""

    def __init__(self, engine: BacktestEngine = None):
        self.engine = engine or BacktestEngine()

    def grid_search(
        self,
        df: pd.DataFrame,
        strategy_fn: Callable,
        param_grid: dict,
        metric: str = 'sharpe_ratio',
        strategy_name: str = "Strategy",
        symbol: str = "BTCUSDT",
        timeframe: str = "1h",
    ) -> dict:
        """
        网格搜索优化
        
        Args:
            df: K 线数据
            strategy_fn: 策略函数
            param_grid: 参数网格 {
                'fast_period': [3, 5, 8, 10],
                'slow_period': [15, 20, 30],
            }
            metric: 优化目标 (sharpe_ratio, total_return, win_rate, profit_factor)
        
        Returns:
            {
                'best_params': {...},
                'best_score': float,
                'all_results': [...],
            }
        """
        # 生成参数组合
        param_names = list(param_grid.keys())
        param_values = list(param_grid.values())
        combinations = list(itertools.product(*param_values))

        logger.info(f"Grid search: {len(combinations)} combinations for {strategy_name}")

        results = []
        for i, combo in enumerate(combinations):
            params = dict(zip(param_names, combo))

            try:
                result = self.engine.run(
                    df=df,
                    strategy_fn=strategy_fn,
                    strategy_params=params,
                    strategy_name=strategy_name,
                    symbol=symbol,
                    timeframe=timeframe,
                )

                score = getattr(result, metric, 0)
                results.append({
                    'params': params,
                    'score': score,
                    'result': result.to_dict(),
                })

                if (i + 1) % 10 == 0:
                    logger.info(f"  Progress: {i+1}/{len(combinations)}")

            except Exception as e:
                logger.warning(f"  Failed with params {params}: {e}")
                results.append({
                    'params': params,
                    'score': -999,
                    'error': str(e),
                })

        # 排序找最优
        results.sort(key=lambda x: x['score'], reverse=True)
        best = results[0]

        logger.info(f"Best params: {best['params']}, {metric}: {best['score']:.4f}")

        return {
            'best_params': best['params'],
            'best_score': best['score'],
            'metric': metric,
            'total_combinations': len(combinations),
            'all_results': results[:20],  # 只返回 top 20
        }

    def random_search(
        self,
        df: pd.DataFrame,
        strategy_fn: Callable,
        param_ranges: dict,
        n_trials: int = 50,
        metric: str = 'sharpe_ratio',
        strategy_name: str = "Strategy",
        symbol: str = "BTCUSDT",
        timeframe: str = "1h",
    ) -> dict:
        """
        随机搜索优化
        
        Args:
            param_ranges: 参数范围 {
                'fast_period': (3, 20, 'int'),     # (min, max, type)
                'slow_period': (15, 100, 'int'),
                'stop_loss': (0.01, 0.1, 'float'),
            }
        """
        logger.info(f"Random search: {n_trials} trials for {strategy_name}")

        results = []
        for i in range(n_trials):
            params = {}
            for name, (low, high, ptype) in param_ranges.items():
                if ptype == 'int':
                    params[name] = np.random.randint(low, high + 1)
                else:
                    params[name] = np.random.uniform(low, high)

            try:
                result = self.engine.run(
                    df=df,
                    strategy_fn=strategy_fn,
                    strategy_params=params,
                    strategy_name=strategy_name,
                    symbol=symbol,
                    timeframe=timeframe,
                )

                score = getattr(result, metric, 0)
                results.append({
                    'params': params,
                    'score': score,
                    'result': result.to_dict(),
                })

            except Exception as e:
                logger.warning(f"  Trial {i+1} failed: {e}")

        results.sort(key=lambda x: x['score'], reverse=True)
        best = results[0] if results else {'params': {}, 'score': 0}

        return {
            'best_params': best['params'],
            'best_score': best['score'],
            'metric': metric,
            'total_trials': n_trials,
            'all_results': results[:20],
        }

    def walk_forward(
        self,
        df: pd.DataFrame,
        strategy_fn: Callable,
        param_grid: dict,
        n_splits: int = 5,
        train_ratio: float = 0.7,
        metric: str = 'sharpe_ratio',
        strategy_name: str = "Strategy",
        symbol: str = "BTCUSDT",
        timeframe: str = "1h",
    ) -> dict:
        """
        Walk-Forward 分析 (滚动窗口优化)
        避免过拟合的关键方法
        
        将数据分成 n_splits 个窗口，每个窗口:
        1. 在训练集上优化参数
        2. 在测试集上验证
        """
        total_len = len(df)
        window_size = total_len // n_splits
        train_size = int(window_size * train_ratio)
        test_size = window_size - train_size

        logger.info(f"Walk-forward: {n_splits} splits, train={train_size}, test={test_size}")

        oos_results = []  # out-of-sample results

        for split in range(n_splits):
            start = split * window_size
            train_end = start + train_size
            test_end = min(start + window_size, total_len)

            train_df = df.iloc[start:train_end]
            test_df = df.iloc[train_end:test_end]

            # 在训练集上网格搜索
            train_result = self.grid_search(
                df=train_df,
                strategy_fn=strategy_fn,
                param_grid=param_grid,
                metric=metric,
                strategy_name=f"{strategy_name}_train_{split}",
                symbol=symbol,
                timeframe=timeframe,
            )

            best_params = train_result['best_params']

            # 在测试集上验证
            test_result = self.engine.run(
                df=test_df,
                strategy_fn=strategy_fn,
                strategy_params=best_params,
                strategy_name=f"{strategy_name}_test_{split}",
                symbol=symbol,
                timeframe=timeframe,
            )

            oos_results.append({
                'split': split,
                'best_params': best_params,
                'train_score': train_result['best_score'],
                'test_score': getattr(test_result, metric, 0),
                'test_result': test_result.to_dict(),
            })

            logger.info(f"  Split {split}: train={train_result['best_score']:.4f}, test={getattr(test_result, metric, 0):.4f}")

        # 汇总
        avg_train = np.mean([r['train_score'] for r in oos_results])
        avg_test = np.mean([r['test_score'] for r in oos_results])
        stability = avg_test / avg_train if avg_train != 0 else 0

        return {
            'n_splits': n_splits,
            'avg_train_score': round(avg_train, 4),
            'avg_test_score': round(avg_test, 4),
            'stability_ratio': round(stability, 4),  # 越接近 1 越好
            'is_overfit': stability < 0.5,  # 稳定性 < 50% 可能过拟合
            'splits': oos_results,
        }


class GeneticOptimizer:
    """遗传算法优化器"""

    def __init__(
        self,
        engine: BacktestEngine = None,
        population_size: int = 20,
        generations: int = 10,
        mutation_rate: float = 0.1,
        crossover_rate: float = 0.7,
    ):
        self.engine = engine or BacktestEngine()
        self.pop_size = population_size
        self.generations = generations
        self.mutation_rate = mutation_rate
        self.crossover_rate = crossover_rate

    def optimize(
        self,
        df: pd.DataFrame,
        strategy_fn: Callable,
        param_ranges: dict,
        metric: str = 'sharpe_ratio',
        strategy_name: str = "Strategy",
        symbol: str = "BTCUSDT",
        timeframe: str = "1h",
    ) -> dict:
        """
        遗传算法优化
        
        Args:
            param_ranges: {
                'fast_period': {'min': 3, 'max': 20, 'type': 'int'},
                'slow_period': {'min': 15, 'max': 100, 'type': 'int'},
                'stop_loss': {'min': 0.01, 'max': 0.1, 'type': 'float'},
            }
        """
        logger.info(f"Genetic optimization: pop={self.pop_size}, gen={self.generations}")

        # 初始化种群
        population = self._init_population(param_ranges)
        best_ever = None

        for gen in range(self.generations):
            # 评估适应度
            fitness_scores = []
            for params in population:
                try:
                    result = self.engine.run(
                        df=df,
                        strategy_fn=strategy_fn,
                        strategy_params=params,
                        strategy_name=strategy_name,
                        symbol=symbol,
                        timeframe=timeframe,
                    )
                    score = getattr(result, metric, 0)
                    fitness_scores.append((params, score))
                except Exception:
                    fitness_scores.append((params, -999))

            # 排序
            fitness_scores.sort(key=lambda x: x[1], reverse=True)

            # 记录最优
            if best_ever is None or fitness_scores[0][1] > best_ever[1]:
                best_ever = fitness_scores[0]

            logger.info(f"  Gen {gen+1}: best={fitness_scores[0][1]:.4f}, avg={np.mean([f[1] for f in fitness_scores]):.4f}")

            # 选择 + 交叉 + 变异
            population = self._evolve(fitness_scores, param_ranges)

        return {
            'best_params': best_ever[0],
            'best_score': best_ever[1],
            'metric': metric,
            'generations': self.generations,
        }

    def _init_population(self, param_ranges: dict) -> list:
        population = []
        for _ in range(self.pop_size):
            params = {}
            for name, spec in param_ranges.items():
                if spec['type'] == 'int':
                    params[name] = np.random.randint(spec['min'], spec['max'] + 1)
                else:
                    params[name] = np.random.uniform(spec['min'], spec['max'])
            population.append(params)
        return population

    def _evolve(self, fitness_scores: list, param_ranges: dict) -> list:
        # 精英保留
        elite_count = max(2, self.pop_size // 5)
        new_pop = [fs[0] for fs in fitness_scores[:elite_count]]

        # 生成新个体
        while len(new_pop) < self.pop_size:
            # 锦标赛选择
            parent1 = self._tournament_select(fitness_scores)
            parent2 = self._tournament_select(fitness_scores)

            # 交叉
            if np.random.random() < self.crossover_rate:
                child = self._crossover(parent1, parent2, param_ranges)
            else:
                child = parent1.copy()

            # 变异
            if np.random.random() < self.mutation_rate:
                child = self._mutate(child, param_ranges)

            new_pop.append(child)

        return new_pop[:self.pop_size]

    def _tournament_select(self, fitness_scores: list, k: int = 3) -> dict:
        candidates = [fitness_scores[i] for i in np.random.choice(len(fitness_scores), k, replace=False)]
        return max(candidates, key=lambda x: x[1])[0]

    def _crossover(self, p1: dict, p2: dict, param_ranges: dict) -> dict:
        child = {}
        for name in p1:
            if np.random.random() < 0.5:
                child[name] = p1[name]
            else:
                child[name] = p2[name]
        return child

    def _mutate(self, params: dict, param_ranges: dict) -> dict:
        mutated = params.copy()
        name = np.random.choice(list(param_ranges.keys()))
        spec = param_ranges[name]

        if spec['type'] == 'int':
            mutated[name] = np.random.randint(spec['min'], spec['max'] + 1)
        else:
            mutated[name] = np.random.uniform(spec['min'], spec['max'])

        return mutated
