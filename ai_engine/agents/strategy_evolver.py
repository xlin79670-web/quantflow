"""
策略进化器 Agent
分析策略表现 → 生成改进方案 → 回测验证 → A/B 测试
"""

import json
from typing import Optional

import numpy as np
from scipy import stats

from llm_gateway.router import LLMRouter, TaskType


class StrategyEvolverAgent:
    """策略进化器 - AI 驱动的策略自优化"""

    SYSTEM_PROMPT = """你是一个量化策略优化专家。你的任务是分析交易策略的表现，找出问题，并提出具体的改进方案。

分析维度：
1. 胜率分析：胜率是否合理？亏损交易的平均亏损是否远大于盈利交易的平均盈利？
2. 时机分析：信号触发时机是否准确？是否存在假信号？
3. 风控分析：止损止盈设置是否合理？
4. 市场适应性：策略在不同市场环境下表现如何？
5. 参数敏感性：当前参数是否最优？

改进方案要求：
1. 每次提出 3 个改进方案，从保守到激进
2. 每个方案只修改一个方面（参数/逻辑/风控）
3. 给出修改后的代码
4. 解释修改理由

输出 JSON 格式:
{
    "analysis": {
        "summary": "表现总结",
        "strengths": ["优点1", "优点2"],
        "weaknesses": ["弱点1", "弱点2"],
        "root_cause": "主要问题的根因分析"
    },
    "suggestions": [
        {
            "name": "方案名称",
            "type": "parameter|logic|risk",
            "description": "修改说明",
            "changes": {"修改的参数或逻辑": "新值"},
            "expected_impact": "预期效果",
            "risk_level": "low|medium|high"
        }
    ]
}
"""

    def __init__(self, llm_router: LLMRouter):
        self.llm = llm_router

    async def analyze_and_suggest(
        self,
        strategy: dict,
        performance: list = None,
        trades: list = None,
    ) -> dict:
        """
        分析策略表现并提出改进建议
        
        Args:
            strategy: 策略信息（包含 source_code, parameters 等）
            performance: 历史性能数据
            trades: 交易记录
        """
        # 计算统计数据
        stats = self._calculate_stats(trades) if trades else {}

        # 构建分析 Prompt
        prompt = f"""请分析以下量化策略的表现，并提出改进建议：

## 策略信息
- 名称: {strategy.get('name', 'N/A')}
- 类型: {strategy.get('type', 'N/A')}
- 标的: {strategy.get('symbol', 'N/A')}
- 时间周期: {strategy.get('timeframe', 'N/A')}
- 当前参数: {json.dumps(strategy.get('parameters', {}), ensure_ascii=False)}

## 策略代码
```python
{strategy.get('source_code', 'N/A')}
```

## 统计数据
{json.dumps(stats, ensure_ascii=False, indent=2)}

## 历史性能
{json.dumps(performance[:10] if performance else [], ensure_ascii=False, indent=2)}

## 最近交易记录（最多 20 笔）
{json.dumps(trades[:20] if trades else [], ensure_ascii=False, indent=2)}

请深入分析策略的优缺点，找出亏损的根本原因，并提出 3 个具体的改进方案。
输出严格的 JSON 格式。
"""

        result = await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.REASONING,
            system_prompt=self.SYSTEM_PROMPT,
        )

        # 为每个建议生成回测代码
        if "suggestions" in result:
            for suggestion in result["suggestions"]:
                suggestion["backtest_ready"] = True

        result["original_strategy"] = {
            "id": strategy.get("id"),
            "name": strategy.get("name"),
            "parameters": strategy.get("parameters"),
        }

        return result

    async def generate_variant(
        self,
        strategy: dict,
        modification: dict,
    ) -> dict:
        """
        生成策略变体（修改后的版本）
        
        Args:
            strategy: 原始策略
            modification: 修改方案
        """
        prompt = f"""请根据以下修改方案，生成策略的变体版本：

## 原始策略代码
```python
{strategy.get('source_code', '')}
```

## 原始参数
{json.dumps(strategy.get('parameters', {}), ensure_ascii=False)}

## 修改方案
{json.dumps(modification, ensure_ascii=False, indent=2)}

请输出修改后的完整策略代码和新参数。
输出 JSON: {{"source_code": "完整代码", "parameters": {{新参数}}}}
"""

        result = await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.CODE_GENERATION,
        )

        return result

    def _calculate_stats(self, trades: list) -> dict:
        """计算交易统计数据"""
        if not trades:
            return {}

        pnls = [t.get("pnl", 0) for t in trades if t.get("pnl") is not None]
        if not pnls:
            return {"total_trades": len(trades)}

        pnl_array = np.array(pnls)
        winning = pnl_array[pnl_array > 0]
        losing = pnl_array[pnl_array < 0]

        return {
            "total_trades": len(trades),
            "winning_trades": len(winning),
            "losing_trades": len(losing),
            "win_rate": len(winning) / len(pnls) * 100 if pnls else 0,
            "total_return": float(np.sum(pnl_array)),
            "avg_return": float(np.mean(pnl_array)),
            "avg_win": float(np.mean(winning)) if len(winning) > 0 else 0,
            "avg_loss": float(np.mean(losing)) if len(losing) > 0 else 0,
            "max_win": float(np.max(pnl_array)),
            "max_loss": float(np.min(pnl_array)),
            "profit_factor": abs(float(np.sum(winning) / np.sum(losing))) if len(losing) > 0 and np.sum(losing) != 0 else float('inf'),
            "std_dev": float(np.std(pnl_array)),
            "sharpe": float(np.mean(pnl_array) / np.std(pnl_array)) if np.std(pnl_array) > 0 else 0,
        }

    async def run_ab_test(
        self,
        strategy_a_trades: list,
        strategy_b_trades: list,
        confidence_level: float = 0.95,
    ) -> dict:
        """
        A/B 测试：比较两个策略的统计显著性
        
        Args:
            strategy_a_trades: 策略 A 的交易记录
            strategy_b_trades: 策略 B 的交易记录
            confidence_level: 置信水平
        """
        pnls_a = [t.get("pnl", 0) for t in strategy_a_trades if t.get("pnl") is not None]
        pnls_b = [t.get("pnl", 0) for t in strategy_b_trades if t.get("pnl") is not None]

        if len(pnls_a) < 5 or len(pnls_b) < 5:
            return {
                "status": "insufficient_data",
                "message": "交易次数不足，至少需要 5 笔交易才能进行 A/B 测试",
                "trades_a": len(pnls_a),
                "trades_b": len(pnls_b),
            }

        arr_a = np.array(pnls_a)
        arr_b = np.array(pnls_b)

        # Welch's t-test
        t_stat, p_value = stats.ttest_ind(arr_b, arr_a, equal_var=False)

        # Cohen's d (效应量)
        pooled_std = np.sqrt((arr_a.std()**2 + arr_b.std()**2) / 2)
        cohens_d = (arr_b.mean() - arr_a.mean()) / pooled_std if pooled_std > 0 else 0

        # 判定结果
        alpha = 1 - confidence_level
        if p_value < alpha:
            if arr_b.mean() > arr_a.mean():
                winner = "B"
                recommendation = "策略 B 显著优于策略 A，建议替换"
            else:
                winner = "A"
                recommendation = "策略 A 显著优于策略 B，建议保留"
        else:
            winner = "inconclusive"
            recommendation = "两者无显著差异，建议继续观察"

        return {
            "status": "completed",
            "winner": winner,
            "recommendation": recommendation,
            "statistics": {
                "mean_a": float(arr_a.mean()),
                "mean_b": float(arr_b.mean()),
                "std_a": float(arr_a.std()),
                "std_b": float(arr_b.std()),
                "t_statistic": float(t_stat),
                "p_value": float(p_value),
                "cohens_d": float(cohens_d),
                "trades_a": len(pnls_a),
                "trades_b": len(pnls_b),
            },
            "interpretation": {
                "effect_size": "small" if abs(cohens_d) < 0.5 else "medium" if abs(cohens_d) < 0.8 else "large",
                "confidence": confidence_level * 100,
            }
        }
