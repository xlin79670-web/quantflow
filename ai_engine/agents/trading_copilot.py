"""
交易助手 Agent - AI 对话式交互
回答交易问题、分析策略表现、执行操作建议
"""

import json
from typing import Optional

from llm_gateway.router import LLMRouter, TaskType


class TradingCopilotAgent:
    """AI 交易助手 - 对话式交互"""

    SYSTEM_PROMPT = """你是 QuantFlow AI 交易助手，一个专业的量化交易分析师和顾问。

你的职责：
1. 回答用户关于交易策略、市场走势的问题
2. 分析策略的盈亏原因，给出具体建议
3. 解读市场数据和新闻事件对交易的影响
4. 提供风控建议
5. 用通俗易懂的语言解释复杂的量化概念

回答风格：
- 简洁直接，不说废话
- 用数据说话，给出具体数字
- 适当使用 emoji 让回答更生动
- 涉及风险时要明确提醒
- 中文回答

你可以访问以下上下文信息：
- 用户的策略列表和状态
- 最近的交易记录
- 当前持仓信息
"""

    def __init__(self, llm_router: LLMRouter):
        self.llm = llm_router

    async def chat(
        self,
        message: str,
        user_id: str,
        strategies: list = None,
        trades: list = None,
        extra_context: str = "",
    ) -> dict:
        """
        处理用户对话
        
        Args:
            message: 用户消息
            user_id: 用户 ID
            strategies: 用户的策略列表
            trades: 最近交易记录
            extra_context: 额外上下文
        """
        # 构建上下文
        context_parts = []

        if strategies:
            context_parts.append("## 用户策略\n" + self._format_strategies(strategies))

        if trades:
            context_parts.append("## 最近交易\n" + self._format_trades(trades[:10]))

        if extra_context:
            context_parts.append(f"## 额外信息\n{extra_context}")

        context = "\n\n".join(context_parts)

        prompt = f"""{context}

## 用户提问
{message}

请根据以上信息回答用户的问题。如果需要查看具体数据才能回答，请说明需要什么数据。
"""

        response = await self.llm.call(
            prompt=prompt,
            task_type=TaskType.CHAT,
            system_prompt=self.SYSTEM_PROMPT,
            temperature=0.7,
            max_tokens=2000,
        )

        # 分析是否需要执行操作
        action = self._detect_action(message, response)

        return {
            "response": response,
            "action": action,
        }

    def _format_strategies(self, strategies: list) -> str:
        """格式化策略信息"""
        lines = []
        for s in strategies:
            status_emoji = {
                "running": "🟢", "paused": "🟡", "stopped": "🔴", "draft": "⚪"
            }.get(s.get("status", ""), "⚪")
            lines.append(
                f"- {status_emoji} **{s.get('name', 'N/A')}** | "
                f"类型: {s.get('type', '')} | "
                f"标的: {s.get('symbol', '')} | "
                f"周期: {s.get('timeframe', '')} | "
                f"状态: {s.get('status', '')}"
            )
        return "\n".join(lines) if lines else "暂无策略"

    def _format_trades(self, trades: list) -> str:
        """格式化交易记录"""
        lines = []
        for t in trades[:10]:
            pnl = t.get("pnl")
            pnl_str = f"{pnl:+.2f}%" if pnl is not None else "N/A"
            emoji = "📈" if pnl and pnl > 0 else "📉" if pnl and pnl < 0 else "➡️"
            lines.append(
                f"- {emoji} {t.get('symbol', '')} | "
                f"{t.get('side', '').upper()} | "
                f"价格: {t.get('price', '')} | "
                f"盈亏: {pnl_str}"
            )
        return "\n".join(lines) if lines else "暂无交易记录"

    def _detect_action(self, question: str, response: str) -> Optional[dict]:
        """检测对话中是否包含需要执行的操作"""
        question_lower = question.lower()

        # 暂停策略
        if any(kw in question_lower for kw in ["暂停", "停止", "pause", "stop"]):
            if any(kw in question_lower for kw in ["策略", "strategy", "所有", "全部"]):
                return {"type": "pause_strategy", "confirmed": False}

        # 修改止损
        if any(kw in question_lower for kw in ["止损", "stop loss", "stoploss"]):
            if any(kw in question_lower for kw in ["改成", "改为", "设置", "调整", "change"]):
                return {"type": "modify_stop_loss", "confirmed": False}

        # 查看持仓
        if any(kw in question_lower for kw in ["持仓", "仓位", "position"]):
            return {"type": "view_positions", "confirmed": True}

        return None
