#!/usr/bin/env python3
"""
AI 策略进化实测
模拟完整进化流程: 基准策略 → AI 分析 → 参数变异 → 回测验证 → A/B 统计检验
"""

import json
import time
import sys
from datetime import datetime
from dataclasses import dataclass
from typing import Optional, List, Dict, Tuple

import numpy as np
import pandas as pd
from scipy import stats


# ==================== 数据生成 (与回测脚本一致) ====================

def generate_market_data(days=90, seed=42):
    np.random.seed(seed)
    n = days * 24
    dates = pd.date_range(end=datetime.now(), periods=n, freq='h')

    base = 60000
    rets = np.random.normal(0.0001, 0.015, n)
    vol = np.ones(n)
    for i in range(1, n):
        vol[i] = 0.95 * vol[i-1] + 0.05 * abs(rets[i-1]) / 0.015
    rets = rets * vol + np.sin(np.linspace(0, 4*np.pi, n)) * 0.0003

    close = base * np.cumprod(1 + rets)
    high = close * (1 + np.abs(np.random.normal(0, 0.005, n)))
    low = close * (1 - np.abs(np.random.normal(0, 0.005, n)))
    open_p = np.roll(close, 1); open_p[0] = base
    volume = np.random.lognormal(20, 0.5, n) * 1e6

    return pd.DataFrame({
        'open': open_p, 'high': high, 'low': low, 'close': close, 'volume': volume,
    }, index=dates)


# ==================== 策略库 ====================

@dataclass
class Signal:
    action: str
    price: float
    time: datetime
    reason: str = ""
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None


def ma_cross(df, p):
    fast, slow = p['fast'], p['slow']
    df = df.copy()
    df['mf'] = df['close'].rolling(fast).mean()
    df['ms'] = df['close'].rolling(slow).mean()
    sigs, pos = [], None
    for i in range(slow, len(df)):
        pr = df['close'].iloc[i]
        if df['mf'].iloc[i] > df['ms'].iloc[i] and df['mf'].iloc[i-1] <= df['ms'].iloc[i-1] and not pos:
            sigs.append(Signal('buy', pr, df.index[i], f"MA金叉", p.get('sl', 0.03), p.get('tp', 0.06)))
            pos = True
        elif df['mf'].iloc[i] < df['ms'].iloc[i] and df['mf'].iloc[i-1] >= df['ms'].iloc[i-1] and pos:
            sigs.append(Signal('sell', pr, df.index[i], f"MA死叉"))
            pos = None
    return sigs

def rsi_strategy(df, p):
    period, oversold, overbought = p['period'], p['oversold'], p['overbought']
    df = df.copy()
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(period).mean()
    df['rsi'] = 100 - 100 / (1 + gain / loss)
    sigs, pos = [], None
    for i in range(period, len(df)):
        r = df['rsi'].iloc[i]; pr = df['close'].iloc[i]
        if r < oversold and not pos:
            sigs.append(Signal('buy', pr, df.index[i], f"RSI={r:.0f}", p.get('sl', 0.03), p.get('tp', 0.06)))
            pos = True
        elif r > overbought and pos:
            sigs.append(Signal('sell', pr, df.index[i], f"RSI={r:.0f}"))
            pos = None
    return sigs

def bollinger(df, p):
    period, std_m = p['period'], p['std']
    df = df.copy()
    df['mid'] = df['close'].rolling(period).mean()
    df['up'] = df['mid'] + std_m * df['close'].rolling(period).std()
    df['lo'] = df['mid'] - std_m * df['close'].rolling(period).std()
    sigs, pos = [], None
    for i in range(period, len(df)):
        pr = df['close'].iloc[i]
        if pr <= df['lo'].iloc[i] and not pos:
            sigs.append(Signal('buy', pr, df.index[i], "触及下轨", p.get('sl', 0.03), p.get('tp', 0.05)))
            pos = True
        elif pr >= df['up'].iloc[i] and pos:
            sigs.append(Signal('sell', pr, df.index[i], "触及上轨"))
            pos = None
    return sigs

def macd_strategy(df, p):
    fast, slow, sig_p = p['fast'], p['slow'], p['signal']
    df = df.copy()
    df['ef'] = df['close'].ewm(span=fast, adjust=False).mean()
    df['es'] = df['close'].ewm(span=slow, adjust=False).mean()
    df['macd'] = df['ef'] - df['es']
    df['sig'] = df['macd'].ewm(span=sig_p, adjust=False).mean()
    df['hist'] = df['macd'] - df['sig']
    sigs, pos = [], None
    for i in range(slow + sig_p, len(df)):
        h, hp = df['hist'].iloc[i], df['hist'].iloc[i-1]
        pr = df['close'].iloc[i]
        if h > 0 and hp <= 0 and not pos:
            sigs.append(Signal('buy', pr, df.index[i], "MACD转正", p.get('sl', 0.04), p.get('tp', 0.08)))
            pos = True
        elif h < 0 and hp >= 0 and pos:
            sigs.append(Signal('sell', pr, df.index[i], "MACD转负"))
            pos = None
    return sigs


# ==================== 回测引擎 ====================

def backtest(df, strategy_fn, params, fee=0.001, slippage=0.0005):
    signals = strategy_fn(df, params)
    trades, capital, pos = [], 10000, None
    signal_map = {s.time: s for s in signals}

    for idx, row in df.iterrows():
        price, low, high = row['close'], row['low'], row['high']

        if pos:
            sl, tp = pos.get('sl'), pos.get('tp')
            ep, er = None, None
            if sl and low <= sl: ep, er = sl, "止损"
            elif tp and high >= tp: ep, er = tp, "止盈"
            if er:
                pnl = (ep - pos['e']) / pos['e'] - fee * 2
                trades.append({'entry': pos['e'], 'exit': ep, 'pnl': pnl, 'reason_in': pos['r'], 'reason_out': er, 'entry_t': pos['t'], 'exit_t': idx})
                capital *= (1 + pnl)
                pos = None

        if idx in signal_map:
            s = signal_map[idx]
            if s.action == 'buy' and not pos:
                e = s.price * (1 + slippage)
                pos = {'e': e, 't': idx, 'r': s.reason, 'sl': e * (1 - (s.stop_loss or 0.03)), 'tp': e * (1 + (s.take_profit or 0.06))}
            elif s.action == 'sell' and pos:
                ex = s.price * (1 - slippage)
                pnl = (ex - pos['e']) / pos['e'] - fee * 2
                trades.append({'entry': pos['e'], 'exit': ex, 'pnl': pnl, 'reason_in': pos['r'], 'reason_out': s.reason, 'entry_t': pos['t'], 'exit_t': idx})
                capital *= (1 + pnl)
                pos = None

    if pos:
        last = df.iloc[-1]['close']
        pnl = (last - pos['e']) / pos['e'] - fee * 2
        trades.append({'entry': pos['e'], 'exit': last, 'pnl': pnl, 'reason_in': pos['r'], 'reason_out': '结束', 'entry_t': pos['t'], 'exit_t': df.index[-1]})
        capital *= (1 + pnl)

    return calc_metrics(trades, capital)

def calc_metrics(trades, final_capital):
    n = len(trades)
    if n == 0:
        return {'total_return': 0, 'sharpe': 0, 'max_dd': 0, 'win_rate': 0, 'trades': 0, 'pf': 0, 'avg_win': 0, 'avg_loss': 0, 'final': final_capital, 'trades_list': []}

    wins = [t for t in trades if t['pnl'] > 0]
    losses = [t for t in trades if t['pnl'] <= 0]
    pnls = [t['pnl'] for t in trades]

    total_ret = (final_capital - 10000) / 10000 * 100
    win_rate = len(wins) / n * 100
    avg_win = np.mean([t['pnl'] for t in wins]) * 100 if wins else 0
    avg_loss = np.mean([t['pnl'] for t in losses]) * 100 if losses else 0
    total_profit = sum(t['pnl'] for t in wins)
    total_loss = abs(sum(t['pnl'] for t in losses))
    pf = total_profit / total_loss if total_loss > 0 else 999

    # 简化夏普
    if len(pnls) > 1:
        sharpe = np.mean(pnls) / np.std(pnls) * np.sqrt(len(pnls)) if np.std(pnls) > 0 else 0
    else:
        sharpe = 0

    # 最大回撤
    eq = [10000]
    for t in trades:
        eq.append(eq[-1] * (1 + t['pnl']))
    eq_arr = np.array(eq)
    peak = np.maximum.accumulate(eq_arr)
    dd = (eq_arr - peak) / peak
    max_dd = abs(dd.min()) * 100

    # 连胜连亏
    mw = ml = cw = cl = 0
    for t in trades:
        if t['pnl'] > 0: cw += 1; cl = 0; mw = max(mw, cw)
        else: cl += 1; cw = 0; ml = max(ml, cl)

    return {
        'total_return': total_ret, 'sharpe': sharpe, 'max_dd': max_dd,
        'win_rate': win_rate, 'trades': n, 'pf': pf,
        'avg_win': avg_win, 'avg_loss': avg_loss,
        'final': final_capital, 'max_win_streak': mw, 'max_loss_streak': ml,
        'trades_list': trades,
    }


# ==================== AI 分析引擎 (本地模拟) ====================

class AIAnalyst:
    """模拟 LLM 的策略分析能力"""

    def analyze_performance(self, name, metrics, params) -> dict:
        """分析策略表现，输出诊断报告"""
        report = {
            'strategy': name,
            'params': params,
            'diagnosis': {},
            'suggestions': [],
        }

        # 诊断
        wr = metrics['win_rate']
        pf = metrics['pf']
        dd = metrics['max_dd']
        sr = metrics['sharpe']
        n = metrics['trades']
        avg_w = metrics['avg_win']
        avg_l = metrics['avg_loss']

        issues = []
        strengths = []

        # 胜率分析
        if wr < 40:
            issues.append(f"胜率过低({wr:.0f}%)，信号质量差")
        elif wr > 55:
            strengths.append(f"胜率良好({wr:.0f}%)")

        # 盈亏比分析
        if pf < 1.2:
            issues.append(f"盈亏比偏低({pf:.2f}x)，盈利不足以覆盖亏损")
        elif pf > 1.8:
            strengths.append(f"盈亏比优秀({pf:.2f}x)")

        # 回撤分析
        if dd > 25:
            issues.append(f"最大回撤过大({dd:.1f}%)，风控不足")
        elif dd < 15:
            strengths.append(f"回撤可控({dd:.1f}%)")

        # 交易频率
        if n > 80:
            issues.append(f"交易过于频繁({n}笔)，可能产生过多手续费")
        elif n < 10:
            issues.append(f"交易过少({n}笔)，统计意义不足")

        # 平均盈亏不对称
        if abs(avg_l) > avg_w * 1.5:
            issues.append(f"亏损交易平均亏损({avg_l:.1f}%)远大于盈利({avg_w:.1f}%)")

        # 夏普
        if sr < 1:
            issues.append(f"夏普比率偏低({sr:.2f})，风险调整收益不足")
        elif sr > 2:
            strengths.append(f"夏普比率优秀({sr:.2f})")

        report['diagnosis'] = {
            'issues': issues,
            'strengths': strengths,
            'overall': 'good' if len(issues) <= 1 else 'needs_improvement' if len(issues) <= 2 else 'poor',
        }

        # 生成优化建议
        report['suggestions'] = self._generate_suggestions(name, params, metrics, issues)

        return report

    def _generate_suggestions(self, name, params, metrics, issues):
        """基于诊断生成优化建议"""
        suggestions = []

        # 通用参数调整
        if 'fast' in params and 'slow' in params:
            fast, slow = params['fast'], params['slow']
            # 如果交易太频繁，增大周期
            if metrics['trades'] > 60:
                suggestions.append({
                    'type': 'param_adjust',
                    'name': '增大均线周期减少噪音',
                    'changes': {'fast': min(fast + 3, 15), 'slow': min(slow + 10, 60)},
                    'reason': f"当前{fast}/{slow}产生{metrics['trades']}笔交易，增大周期可过滤噪音",
                    'risk': 'low',
                })
            # 如果胜率低，增大慢线
            if metrics['win_rate'] < 40:
                suggestions.append({
                    'type': 'param_adjust',
                    'name': '增大慢线确认趋势',
                    'changes': {'slow': min(slow + 15, 80)},
                    'reason': f"胜率{metrics['win_rate']:.0f}%偏低，更长慢线可过滤假信号",
                    'risk': 'low',
                })

        # RSI 调整
        if 'period' in params and 'oversold' in params:
            if metrics['win_rate'] < 45:
                suggestions.append({
                    'type': 'param_adjust',
                    'name': '收紧 RSI 阈值',
                    'changes': {'oversold': max(params.get('oversold', 30) - 5, 15), 'overbought': min(params.get('overbought', 70) + 5, 85)},
                    'reason': "收紧阈值可提高信号质量",
                    'risk': 'medium',
                })

        # 止损止盈调整
        if metrics['avg_loss'] < -4:
            new_sl = max(params.get('sl', 0.03) - 0.005, 0.015)
            suggestions.append({
                'type': 'risk_adjust',
                'name': '收紧止损',
                'changes': {'sl': new_sl},
                'reason': f"平均亏损{metrics['avg_loss']:.1f}%过大，收紧止损控制单笔风险",
                'risk': 'low',
            })

        if metrics['avg_win'] < 3:
            new_tp = min(params.get('tp', 0.06) + 0.01, 0.10)
            suggestions.append({
                'type': 'risk_adjust',
                'name': '放大止盈目标',
                'changes': {'tp': new_tp},
                'reason': f"平均盈利{metrics['avg_win']:.1f}%偏低，放大止盈提高盈亏比",
                'risk': 'medium',
            })

        # 布林带特殊调整
        if 'std' in params:
            if metrics['trades'] > 30:
                suggestions.append({
                    'type': 'param_adjust',
                    'name': '增大布林带宽度',
                    'changes': {'std': min(params['std'] + 0.3, 3.0)},
                    'reason': "减少交易频率，只在极端位置入场",
                    'risk': 'low',
                })

        # MACD 调整
        if 'signal' in params:
            if metrics['trades'] > 80:
                suggestions.append({
                    'type': 'param_adjust',
                    'name': '增大 MACD 信号线周期',
                    'changes': {'signal': min(params['signal'] + 2, 15)},
                    'reason': "减少假信号",
                    'risk': 'low',
                })

        # 组合策略建议
        if metrics['win_rate'] < 45 and metrics['pf'] < 1.3:
            suggestions.append({
                'type': 'logic_enhance',
                'name': '添加成交量确认',
                'changes': {'volume_filter': True, 'vol_mult': 1.3},
                'reason': "低胜率+低盈亏比，需要额外过滤条件",
                'risk': 'medium',
            })

        return suggestions


# ==================== 参数优化器 ====================

class ParamOptimizer:
    """贝叶斯优化 + 遗传算法"""

    def grid_search(self, df, strategy_fn, param_grid, metric='sharpe'):
        """网格搜索"""
        import itertools
        keys = list(param_grid.keys())
        combos = list(itertools.product(*param_grid.values()))

        results = []
        for combo in combos:
            params = dict(zip(keys, combo))
            try:
                m = backtest(df, strategy_fn, params)
                score = m.get(metric, 0)
                results.append((params, score, m))
            except:
                pass

        results.sort(key=lambda x: x[1], reverse=True)
        return results

    def random_search(self, df, strategy_fn, param_ranges, n_trials=50, metric='sharpe'):
        """随机搜索"""
        results = []
        for _ in range(n_trials):
            params = {}
            for k, (lo, hi, typ) in param_ranges.items():
                params[k] = np.random.randint(lo, hi+1) if typ == 'int' else round(np.random.uniform(lo, hi), 4)
            try:
                m = backtest(df, strategy_fn, params)
                results.append((params, m.get(metric, 0), m))
            except:
                pass
        results.sort(key=lambda x: x[1], reverse=True)
        return results

    def genetic_optimize(self, df, strategy_fn, param_ranges, pop_size=20, generations=10, metric='sharpe'):
        """遗传算法"""
        def rand_params():
            return {k: np.random.randint(v[0], v[1]+1) if v[2]=='int' else round(np.random.uniform(v[0], v[1]), 4) for k, v in param_ranges.items()}

        def fitness(params):
            try:
                return backtest(df, strategy_fn, params).get(metric, -999)
            except:
                return -999

        def crossover(p1, p2):
            return {k: p1[k] if np.random.random() < 0.5 else p2[k] for k in p1}

        def mutate(p):
            p = p.copy()
            k = np.random.choice(list(param_ranges.keys()))
            lo, hi, typ = param_ranges[k]
            p[k] = np.random.randint(lo, hi+1) if typ == 'int' else round(np.random.uniform(lo, hi), 4)
            return p

        # 初始化种群
        pop = [(rand_params(), 0) for _ in range(pop_size)]
        pop = [(p, fitness(p)) for p, _ in pop]
        best_ever = max(pop, key=lambda x: x[1])

        for gen in range(generations):
            pop.sort(key=lambda x: x[1], reverse=True)
            if pop[0][1] > best_ever[1]:
                best_ever = pop[0]

            # 精英保留
            elite_n = max(2, pop_size // 5)
            new_pop = [p for p, _ in pop[:elite_n]]

            # 生成新个体
            while len(new_pop) < pop_size:
                # 锦标赛选择
                i1, i2 = np.random.randint(0, pop_size), np.random.randint(0, pop_size)
                p1 = pop[i1][0] if pop[i1][1] > pop[i2][1] else pop[i2][0]
                i1, i2 = np.random.randint(0, pop_size), np.random.randint(0, pop_size)
                p2 = pop[i1][0] if pop[i1][1] > pop[i2][1] else pop[i2][0]
                child = crossover(p1, p2)
                if np.random.random() < 0.2:
                    child = mutate(child)
                new_pop.append(child)

            pop = [(p, fitness(p)) for p in new_pop[:pop_size]]

        return best_ever


# ==================== A/B 测试 ====================

class ABTester:
    """统计显著性检验"""

    def compare(self, trades_a, trades_b, confidence=0.95):
        pnls_a = [t['pnl'] for t in trades_a]
        pnls_b = [t['pnl'] for t in trades_b]

        if len(pnls_a) < 5 or len(pnls_b) < 5:
            return {'status': 'insufficient_data', 'trades_a': len(pnls_a), 'trades_b': len(pnls_b)}

        a, b = np.array(pnls_a), np.array(pnls_b)

        # Welch's t-test
        t_stat, p_val = stats.ttest_ind(b, a, equal_var=False)

        # Cohen's d
        pooled_std = np.sqrt((a.std()**2 + b.std()**2) / 2)
        cohens_d = (b.mean() - a.mean()) / pooled_std if pooled_std > 0 else 0

        alpha = 1 - confidence
        if p_val < alpha:
            winner = 'B' if b.mean() > a.mean() else 'A'
            sig = True
        else:
            winner = 'inconclusive'
            sig = False

        return {
            'status': 'completed',
            'significant': sig,
            'winner': winner,
            'p_value': round(p_val, 6),
            't_statistic': round(t_stat, 4),
            'cohens_d': round(cohens_d, 4),
            'effect_size': 'small' if abs(cohens_d) < 0.5 else 'medium' if abs(cohens_d) < 0.8 else 'large',
            'mean_a': round(a.mean() * 100, 4),
            'mean_b': round(b.mean() * 100, 4),
            'improvement': round((b.mean() - a.mean()) / abs(a.mean()) * 100, 2) if a.mean() != 0 else 0,
        }


# ==================== 主进化流程 ====================

def main():
    print("=" * 70)
    print("🧬 AI 策略进化实测")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # 1. 准备数据
    print("\n📊 Step 1: 准备市场数据")
    df = generate_market_data(days=90)
    print(f"   数据: {len(df)} 根 1h K线, {df.index[0].date()} → {df.index[-1].date()}")
    print(f"   价格: ${df['close'].iloc[0]:,.0f} → ${df['close'].iloc[-1]:,.0f}")

    # 2. 定义基准策略
    print("\n📊 Step 2: 基准策略回测")
    strategies = {
        'ma_cross': {
            'name': '均线交叉 (5/20)',
            'fn': ma_cross,
            'params': {'fast': 5, 'slow': 20, 'sl': 0.03, 'tp': 0.06},
            'ranges': {'fast': (3, 15, 'int'), 'slow': (15, 60, 'int'), 'sl': (0.015, 0.05, 'float'), 'tp': (0.03, 0.10, 'float')},
        },
        'rsi': {
            'name': 'RSI 反转 (14)',
            'fn': rsi_strategy,
            'params': {'period': 14, 'oversold': 30, 'overbought': 70, 'sl': 0.03, 'tp': 0.06},
            'ranges': {'period': (5, 25, 'int'), 'oversold': (15, 40, 'int'), 'overbought': (60, 85, 'int'), 'sl': (0.015, 0.05, 'float'), 'tp': (0.03, 0.10, 'float')},
        },
        'bollinger': {
            'name': '布林带回归',
            'fn': bollinger,
            'params': {'period': 20, 'std': 2.0, 'sl': 0.03, 'tp': 0.05},
            'ranges': {'period': (10, 30, 'int'), 'std': (1.5, 3.0, 'float'), 'sl': (0.015, 0.05, 'float'), 'tp': (0.03, 0.08, 'float')},
        },
        'macd': {
            'name': 'MACD 趋势',
            'fn': macd_strategy,
            'params': {'fast': 12, 'slow': 26, 'signal': 9, 'sl': 0.04, 'tp': 0.08},
            'ranges': {'fast': (5, 15, 'int'), 'slow': (20, 40, 'int'), 'signal': (5, 15, 'int'), 'sl': (0.02, 0.06, 'float'), 'tp': (0.04, 0.12, 'float')},
        },
    }

    baseline_results = {}
    for key, s in strategies.items():
        m = backtest(df, s['fn'], s['params'])
        baseline_results[key] = m
        emoji = "✅" if m['total_return'] > 0 else "❌"
        print(f"   {emoji} {s['name']}: 收益={m['total_return']:+.2f}%, Sharpe={m['sharpe']:.2f}, 胜率={m['win_rate']:.0f}%, {m['trades']}笔")

    # 3. AI 分析
    print("\n📊 Step 3: AI 策略分析")
    analyst = AIAnalyst()
    optimizer = ParamOptimizer()

    analyses = {}
    for key, s in strategies.items():
        report = analyst.analyze_performance(s['name'], baseline_results[key], s['params'])
        analyses[key] = report
        d = report['diagnosis']
        print(f"\n   🔍 {s['name']}:")
        print(f"      状态: {'🟢 良好' if d['overall'] == 'good' else '🟡 需改进' if d['overall'] == 'needs_improvement' else '🔴 较差'}")
        for issue in d['issues']:
            print(f"      ⚠️  {issue}")
        for strength in d['strengths']:
            print(f"      ✅ {strength}")
        print(f"      💡 AI 建议 {len(report['suggestions'])} 项优化:")
        for sug in report['suggestions']:
            print(f"         • {sug['name']}: {sug['reason']}")

    # 4. 遗传算法优化
    print("\n" + "=" * 70)
    print("📊 Step 4: 遗传算法参数优化")
    print("=" * 70)

    evolved_results = {}
    for key, s in strategies.items():
        print(f"\n   🧬 优化 {s['name']}...")
        best_params, best_score = None, -999

        # 先用随机搜索快速定位
        random_results = optimizer.random_search(df, s['fn'], s['ranges'], n_trials=30, metric='sharpe')
        if random_results:
            best_params, best_score = random_results[0][0], random_results[0][1]
            print(f"      随机搜索最优: Sharpe={best_score:.2f}, 参数={best_params}")

        # 再用遗传算法精调
        ga_result = optimizer.genetic_optimize(df, s['fn'], s['ranges'], pop_size=15, generations=8, metric='sharpe')
        if ga_result[1] > best_score:
            best_params, best_score = ga_result[0], ga_result[1]
            print(f"      遗传算法最优: Sharpe={best_score:.2f}, 参数={best_params}")

        # 回测最优参数
        evolved_m = backtest(df, s['fn'], best_params)
        evolved_results[key] = {'metrics': evolved_m, 'params': best_params}

        base_m = baseline_results[key]
        imp = evolved_m['total_return'] - base_m['total_return']
        print(f"      📈 进化结果: 收益 {base_m['total_return']:+.2f}% → {evolved_m['total_return']:+.2f}% ({imp:+.2f}%)")
        print(f"      📊 夏普 {base_m['sharpe']:.2f} → {evolved_m['sharpe']:.2f}")
        print(f"      🎯 胜率 {base_m['win_rate']:.0f}% → {evolved_m['win_rate']:.0f}%")

    # 5. A/B 测试
    print("\n" + "=" * 70)
    print("📊 Step 5: A/B 统计检验")
    print("=" * 70)

    tester = ABTester()
    for key, s in strategies.items():
        base_trades = baseline_results[key]['trades_list']
        evo_trades = evolved_results[key]['metrics']['trades_list']

        ab = tester.compare(base_trades, evo_trades)
        print(f"\n   🧪 {s['name']}:")
        if ab['status'] == 'insufficient_data':
            print(f"      ⚠️ 数据不足 (A:{ab['trades_a']}, B:{ab['trades_b']})")
        else:
            sig_emoji = "✅" if ab['significant'] else "❌"
            print(f"      {sig_emoji} 统计显著: {'是' if ab['significant'] else '否'} (p={ab['p_value']:.4f})")
            print(f"      📊 效应量: Cohen's d={ab['cohens_d']:.3f} ({ab['effect_size']})")
            print(f"      📈 平均收益: A={ab['mean_a']:.2f}% → B={ab['mean_b']:.2f}%")
            print(f"      🎯 改善幅度: {ab['improvement']:+.1f}%")
            if ab['winner'] == 'B':
                print(f"      🏆 进化版胜出!")
            elif ab['winner'] == 'A':
                print(f"      🏆 原版保留")
            else:
                print(f"      🤝 无显著差异")

    # 6. 最终报告
    print("\n" + "=" * 70)
    print("📊 Step 6: 进化总结报告")
    print("=" * 70)

    print(f"\n{'策略':<20} {'原版收益':>10} {'进化收益':>10} {'提升':>8} {'原版夏普':>8} {'进化夏普':>8} {'A/B':>6}")
    print("-" * 75)

    for key, s in strategies.items():
        b = baseline_results[key]
        e = evolved_results[key]['metrics']
        ab = tester.compare(b['trades_list'], e['trades_list'])
        imp = e['total_return'] - b['total_return']
        sig = "✅" if ab.get('significant') and ab.get('winner') == 'B' else "❌" if ab.get('significant') and ab.get('winner') == 'A' else "➖"
        print(f" {s['name']:<20} {b['total_return']:>+9.2f}% {e['total_return']:>+9.2f}% {imp:>+7.2f}% {b['sharpe']:>7.2f} {e['sharpe']:>7.2f}   {sig}")

    # 找最优进化策略
    best_key = max(strategies.keys(), key=lambda k: evolved_results[k]['metrics']['sharpe'])
    best_evo = evolved_results[best_key]
    best_base = baseline_results[best_key]
    best_strat = strategies[best_key]

    print(f"\n🏆 最优进化策略: {best_strat['name']}")
    print(f"   原版参数: {best_strat['params']}")
    print(f"   进化参数: {best_evo['params']}")
    print(f"   收益提升: {best_base['total_return']:+.2f}% → {best_evo['metrics']['total_return']:+.2f}%")
    print(f"   夏普提升: {best_base['sharpe']:.2f} → {best_evo['metrics']['sharpe']:.2f}")

    # 输出 JSON
    output = {
        'evolution_time': datetime.now().isoformat(),
        'symbol': 'BTCUSDT',
        'timeframe': '1h',
        'days': 90,
        'baseline': {k: {
            'name': strategies[k]['name'],
            'params': strategies[k]['params'],
            'total_return': round(v['total_return'], 4),
            'sharpe': round(v['sharpe'], 4),
            'win_rate': round(v['win_rate'], 2),
            'max_drawdown': round(v['max_dd'], 4),
            'trades': v['trades'],
        } for k, v in baseline_results.items()},
        'evolved': {k: {
            'name': strategies[k]['name'],
            'params': v['params'],
            'total_return': round(v['metrics']['total_return'], 4),
            'sharpe': round(v['metrics']['sharpe'], 4),
            'win_rate': round(v['metrics']['win_rate'], 2),
            'max_drawdown': round(v['metrics']['max_dd'], 4),
            'trades': v['metrics']['trades'],
        } for k, v in evolved_results.items()},
    }

    with open('evolution_result.json', 'w') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\n✅ 结果已保存到 evolution_result.json")


if __name__ == "__main__":
    main()
