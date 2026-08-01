"""
回测引擎快速测试
运行: python -m backtest.test_backtest
"""

import asyncio
import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backtest import (
    BacktestEngine, BacktestConfig, fetch_klines, add_indicators,
    list_strategies, get_strategy, ParameterOptimizer,
)


async def test_single_backtest():
    """测试单次回测"""
    print("=" * 60)
    print("📊 测试 1: 单次回测 - 均线交叉策略")
    print("=" * 60)

    # 获取最近 90 天的 BTC 1h K 线
    print("\n📥 获取历史数据...")
    df = await fetch_klines(symbol="BTCUSDT", interval="1h", days=90)
    df = add_indicators(df)
    print(f"   数据: {len(df)} 根 K 线, {df.index[0]} ~ {df.index[-1]}")

    # 运行均线交叉策略
    strategy = get_strategy('ma_cross')
    engine = BacktestEngine(BacktestConfig(initial_capital=10000))

    print("\n⚙️  执行回测...")
    result = engine.run(
        df=df,
        strategy_fn=strategy['fn'],
        strategy_params=strategy['default_params'],
        strategy_name=strategy['name'],
        symbol="BTCUSDT",
        timeframe="1h",
    )

    print(result.summary())

    # 打印最近 5 笔交易
    print("📋 最近 5 笔交易:")
    print("-" * 80)
    for t in result.trades[-5:]:
        emoji = "✅" if t.is_win else "❌"
        print(f"  {emoji} #{t.id} | {t.entry_time.strftime('%m-%d %H:%M')} → {t.exit_time.strftime('%m-%d %H:%M')} | "
              f"{t.side} | {t.entry_price:.2f} → {t.exit_price:.2f} | {t.pnl_pct:+.2f}% | {t.reason_entry}")

    return result


async def test_strategy_comparison():
    """测试多策略对比"""
    print("\n" + "=" * 60)
    print("📊 测试 2: 多策略对比")
    print("=" * 60)

    df = await fetch_klines(symbol="BTCUSDT", interval="1h", days=90)
    df = add_indicators(df)

    engine = BacktestEngine(BacktestConfig(initial_capital=10000))
    strategies = list_strategies()

    results = []
    for s in strategies:
        try:
            result = engine.run(
                df=df,
                strategy_fn=s['fn'] if callable(s.get('fn')) else get_strategy(s['key'])['fn'],
                strategy_params=s['default_params'],
                strategy_name=s['name'],
                symbol="BTCUSDT",
                timeframe="1h",
            )
            results.append(result)
            print(f"  ✅ {s['name']}: {result.total_return:+.2f}% | Sharpe: {result.sharpe_ratio:.2f} | 胜率: {result.win_rate:.1f}%")
        except Exception as e:
            print(f"  ❌ {s['name']}: {e}")

    # 排序
    results.sort(key=lambda x: x.sharpe_ratio, reverse=True)

    print("\n🏆 排名 (按夏普比率):")
    print("-" * 60)
    for i, r in enumerate(results, 1):
        print(f"  {i}. {r.strategy_name}: Sharpe={r.sharpe_ratio:.2f}, 收益={r.total_return:+.2f}%, 回撤={r.max_drawdown:.2f}%")

    return results


async def test_parameter_optimization():
    """测试参数优化"""
    print("\n" + "=" * 60)
    print("📊 测试 3: 参数优化 - 均线交叉")
    print("=" * 60)

    df = await fetch_klines(symbol="BTCUSDT", interval="1h", days=90)
    df = add_indicators(df)

    strategy = get_strategy('ma_cross')

    optimizer = ParameterOptimizer()
    result = optimizer.grid_search(
        df=df,
        strategy_fn=strategy['fn'],
        param_grid={
            'fast_period': [3, 5, 8, 10],
            'slow_period': [15, 20, 30, 50],
            'stop_loss': [0.02, 0.03, 0.05],
            'take_profit': [0.04, 0.06, 0.10],
        },
        metric='sharpe_ratio',
        strategy_name='均线交叉',
        symbol='BTCUSDT',
        timeframe='1h',
    )

    print(f"\n🎯 最优参数: {result['best_params']}")
    print(f"📊 最优夏普: {result['best_score']:.4f}")
    print(f"🔢 搜索组合: {result['total_combinations']}")

    print("\n📋 Top 5 参数组合:")
    print("-" * 60)
    for i, r in enumerate(result['all_results'][:5], 1):
        print(f"  {i}. {r['params']} → Sharpe: {r['score']:.4f}")

    return result


async def main():
    """主测试流程"""
    print("🚀 QuantFlow 回测引擎测试")
    print("=" * 60)

    # 列出可用策略
    print("\n📦 可用策略:")
    for s in list_strategies():
        print(f"  • {s['key']}: {s['name']} - {s['description']}")

    # 运行测试
    await test_single_backtest()
    await test_strategy_comparison()
    await test_parameter_optimization()

    print("\n✅ 所有测试完成!")


if __name__ == "__main__":
    asyncio.run(main())
