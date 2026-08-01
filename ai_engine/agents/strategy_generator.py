"""
策略生成器 Agent
自然语言描述 → 可执行的量化策略代码
"""

import json
from typing import Optional

from llm_gateway.router import LLMRouter, TaskType

# 内置策略模板
STRATEGY_TEMPLATES = {
    "ma_cross": {
        "name": "均线交叉策略",
        "code": '''
import pandas as pd

def strategy(df, params):
    """
    均线交叉策略
    金叉买入，死叉卖出
    """
    fast = params.get("fast_period", 5)
    slow = params.get("slow_period", 20)
    stop_loss = params.get("stop_loss", 0.03)
    take_profit = params.get("take_profit", 0.06)
    
    df["ma_fast"] = df["close"].rolling(fast).mean()
    df["ma_slow"] = df["close"].rolling(slow).mean()
    
    signals = []
    position = None
    
    for i in range(slow, len(df)):
        # 金叉：快线上穿慢线
        if df["ma_fast"].iloc[i] > df["ma_slow"].iloc[i] and \\
           df["ma_fast"].iloc[i-1] <= df["ma_slow"].iloc[i-1]:
            if position is None:
                signals.append({
                    "action": "buy",
                    "price": df["close"].iloc[i],
                    "time": df.index[i],
                    "reason": f"MA{fast} 上穿 MA{slow} (金叉)"
                })
                position = {"entry": df["close"].iloc[i]}
        
        # 死叉：快线下穿慢线
        elif df["ma_fast"].iloc[i] < df["ma_slow"].iloc[i] and \\
             df["ma_fast"].iloc[i-1] >= df["ma_slow"].iloc[i-1]:
            if position is not None:
                pnl = (df["close"].iloc[i] - position["entry"]) / position["entry"]
                signals.append({
                    "action": "sell",
                    "price": df["close"].iloc[i],
                    "time": df.index[i],
                    "pnl": pnl,
                    "reason": f"MA{fast} 下穿 MA{slow} (死叉)"
                })
                position = None
        
        # 止损检查
        elif position and df["low"].iloc[i] <= position["entry"] * (1 - stop_loss):
            signals.append({
                "action": "sell",
                "price": position["entry"] * (1 - stop_loss),
                "time": df.index[i],
                "pnl": -stop_loss,
                "reason": f"触发止损 ({stop_loss*100}%)"
            })
            position = None
    
    return signals
''',
        "default_params": {
            "fast_period": 5,
            "slow_period": 20,
            "stop_loss": 0.03,
            "take_profit": 0.06,
        },
    },
    "rsi_reversal": {
        "name": "RSI 超买超卖策略",
        "code": '''
import pandas as pd

def strategy(df, params):
    """
    RSI 反转策略
    RSI < 超卖线买入，RSI > 超买线卖出
    """
    period = params.get("rsi_period", 14)
    oversold = params.get("oversold", 30)
    overbought = params.get("overbought", 70)
    stop_loss = params.get("stop_loss", 0.03)
    
    # 计算 RSI
    delta = df["close"].diff()
    gain = delta.where(delta > 0, 0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(period).mean()
    rs = gain / loss
    df["rsi"] = 100 - (100 / (1 + rs))
    
    signals = []
    position = None
    
    for i in range(period, len(df)):
        rsi = df["rsi"].iloc[i]
        
        # 超卖买入
        if rsi < oversold and position is None:
            signals.append({
                "action": "buy",
                "price": df["close"].iloc[i],
                "time": df.index[i],
                "reason": f"RSI={rsi:.1f} < {oversold} (超卖)"
            })
            position = {"entry": df["close"].iloc[i]}
        
        # 超买卖出
        elif rsi > overbought and position is not None:
            pnl = (df["close"].iloc[i] - position["entry"]) / position["entry"]
            signals.append({
                "action": "sell",
                "price": df["close"].iloc[i],
                "time": df.index[i],
                "pnl": pnl,
                "reason": f"RSI={rsi:.1f} > {overbought} (超买)"
            })
            position = None
        
        # 止损
        elif position and df["low"].iloc[i] <= position["entry"] * (1 - stop_loss):
            signals.append({
                "action": "sell",
                "price": position["entry"] * (1 - stop_loss),
                "time": df.index[i],
                "pnl": -stop_loss,
                "reason": f"触发止损"
            })
            position = None
    
    return signals
''',
        "default_params": {
            "rsi_period": 14,
            "oversold": 30,
            "overbought": 70,
            "stop_loss": 0.03,
        },
    },
    "grid_trading": {
        "name": "网格交易策略",
        "code": '''
import pandas as pd
import numpy as np

def strategy(df, params):
    """
    网格交易策略
    在价格区间内等距挂单，低买高卖
    """
    upper = params.get("upper_price", 70000)
    lower = params.get("lower_price", 60000)
    grids = params.get("grid_count", 10)
    position_per_grid = params.get("position_per_grid", 0.1)
    
    grid_step = (upper - lower) / grids
    grid_prices = [lower + i * grid_step for i in range(grids + 1)]
    
    signals = []
    holdings = {}  # grid_level -> entry_price
    
    for i in range(len(df)):
        price = df["close"].iloc[i]
        
        for level, grid_price in enumerate(grid_prices):
            # 价格触及网格线 - 买入
            if price <= grid_price and level not in holdings:
                if level > 0 and (level - 1) not in holdings:
                    continue  # 需要下方网格已持仓
                signals.append({
                    "action": "buy",
                    "price": grid_price,
                    "time": df.index[i],
                    "quantity_pct": position_per_grid,
                    "reason": f"网格买入 Level {level} @ {grid_price:.2f}"
                })
                holdings[level] = grid_price
            
            # 价格上涨到上一格 - 卖出
            elif level in holdings and price >= grid_prices[level + 1] if level < len(grid_prices) - 1 else False:
                entry = holdings[level]
                pnl = (grid_prices[level + 1] - entry) / entry
                signals.append({
                    "action": "sell",
                    "price": grid_prices[level + 1],
                    "time": df.index[i],
                    "pnl": pnl,
                    "reason": f"网格卖出 Level {level}"
                })
                del holdings[level]
    
    return signals
''',
        "default_params": {
            "upper_price": 70000,
            "lower_price": 60000,
            "grid_count": 10,
            "position_per_grid": 0.1,
        },
    },
}


class StrategyGeneratorAgent:
    """策略生成器 Agent - 自然语言 → 可执行策略代码"""

    SYSTEM_PROMPT = """你是一个专业的量化交易策略开发专家。你的任务是根据用户的自然语言描述，生成可执行的 Python 量化策略代码。

要求：
1. 代码必须是一个名为 `strategy(df, params)` 的函数
2. `df` 是 pandas DataFrame，包含列: open, high, low, close, volume
3. `params` 是策略参数字典
4. 返回一个信号列表，每个信号是 dict: {action, price, time, reason, pnl?}
5. 代码要完整、可运行、有注释
6. 同时输出推荐的默认参数

输出格式 (JSON):
{
    "name": "策略名称",
    "description": "策略描述",
    "source_code": "完整的 Python 代码",
    "parameters": {"参数名": 默认值, ...},
    "risk_notes": "风险提示"
}
"""

    def __init__(self, llm_router: LLMRouter):
        self.llm = llm_router
        self.templates = STRATEGY_TEMPLATES

    async def generate(
        self,
        description: str,
        symbol: str = "BTCUSDT",
        timeframe: str = "1h",
    ) -> dict:
        """
        根据自然语言描述生成策略
        
        Args:
            description: 用户的策略描述，如 "RSI低于30时买入，高于70时卖出"
            symbol: 交易对
            timeframe: 时间周期
        """
        # 构建 Prompt
        prompt = f"""请根据以下描述生成一个量化交易策略：

## 策略描述
{description}

## 交易对
{symbol}

## 时间周期
{timeframe}

## 参考模板
以下是几个经典策略的代码示例，可以作为参考：

### 均线交叉策略
```python
{self.templates['ma_cross']['code']}
```

### RSI 策略
```python
{self.templates['rsi_reversal']['code']}
```

请根据用户描述生成新的策略代码。如果是上述策略的变体，可以在模板基础上修改。
输出严格的 JSON 格式。
"""

        result = await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.CODE_GENERATION,
            system_prompt=self.SYSTEM_PROMPT,
        )

        # 验证生成的代码
        if "source_code" in result:
            is_valid, error = self._validate_code(result["source_code"])
            if not is_valid:
                # 让 LLM 修复代码
                fix_prompt = f"""以下策略代码有错误，请修复：

```python
{result['source_code']}
```

错误信息: {error}

请输出修复后的完整 JSON。"""
                result = await self.llm.call_json(
                    prompt=fix_prompt,
                    task_type=TaskType.CODE_GENERATION,
                    system_prompt=self.SYSTEM_PROMPT,
                )

        result["symbol"] = symbol
        result["timeframe"] = timeframe
        return result

    async def get_template(self, template_name: str) -> Optional[dict]:
        """获取内置策略模板"""
        return self.templates.get(template_name)

    async def list_templates(self) -> list:
        """列出所有内置模板"""
        return [
            {"key": k, "name": v["name"], "params": v["default_params"]}
            for k, v in self.templates.items()
        ]

    def _validate_code(self, code: str) -> tuple:
        """验证策略代码的基本正确性"""
        try:
            # 基本语法检查
            compile(code, "<strategy>", "exec")
            # 检查是否包含 strategy 函数
            if "def strategy(" not in code:
                return False, "代码中缺少 strategy 函数定义"
            return True, None
        except SyntaxError as e:
            return False, f"语法错误: {e}"
