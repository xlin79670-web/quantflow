"""
风险预判器 Agent
基于宏观事件、市场结构、持仓状态的综合风险评估
"""

import json
from typing import Optional

from llm_gateway.router import LLMRouter, TaskType


class RiskPredictorAgent:
    """风险预判器 - AI 驱动的综合风险评估"""

    SYSTEM_PROMPT = """你是一个专业的金融风险分析师。你的任务是评估当前的市场风险和持仓风险，提供具体的风险预警和应对建议。

风险评估维度：
1. 宏观风险：美联储政策、监管动态、地缘政治
2. 市场结构风险：资金费率、清算数据、期权到期
3. 流动性风险：买卖盘深度、交易所状态
4. 持仓风险：集中度、杠杆水平、相关性
5. 技术风险：交易所 API 稳定性、网络拥堵

风险评分标准：
- 1-3: 低风险 (绿色)
- 4-6: 中等风险 (黄色)
- 7-8: 高风险 (橙色)
- 9-10: 极高风险 (红色) - 建议立即行动

输出 JSON 格式:
{
    "overall_risk": 1-10,
    "risk_level": "low|medium|high|critical",
    "factors": [
        {
            "name": "风险因子",
            "score": 1-10,
            "status": "green|yellow|orange|red",
            "description": "详细说明",
            "trend": "increasing|stable|decreasing"
        }
    ],
    "recommendations": [
        {
            "action": "建议的操作",
            "urgency": "immediate|soon|monitor",
            "reason": "原因"
        }
    ],
    "auto_actions": [
        {
            "trigger": "触发条件",
            "action": "自动执行的操作"
        }
    ]
}
"""

    def __init__(self, llm_router: LLMRouter):
        self.llm = llm_router

    async def assess(
        self,
        positions: list = None,
        market_data: dict = None,
        events: list = None,
    ) -> dict:
        """
        综合风险评估
        
        Args:
            positions: 当前持仓
            market_data: 市场数据
            events: 近期事件
        """
        prompt = f"""请进行综合风险评估：

## 当前持仓
{json.dumps(positions or [], ensure_ascii=False, indent=2)}

## 市场数据
{json.dumps(market_data or {}, ensure_ascii=False, indent=2)}

## 近期重要事件
{json.dumps(events or [], ensure_ascii=False, indent=2)}

请输出完整的风险评估报告，包含风险评分、各因子分析、建议操作和自动响应规则。
输出严格的 JSON 格式。
"""

        result = await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.RISK_ASSESSMENT,
            system_prompt=self.SYSTEM_PROMPT,
        )

        # 添加自动响应建议
        if result.get("overall_risk", 0) >= 8:
            result["auto_actions"] = result.get("auto_actions", [])
            result["auto_actions"].append({
                "trigger": "综合风险评分 >= 8",
                "action": "暂停所有策略，等待人工确认",
            })
        elif result.get("overall_risk", 0) >= 6:
            result["auto_actions"] = result.get("auto_actions", [])
            result["auto_actions"].append({
                "trigger": "综合风险评分 >= 6",
                "action": "收紧止损至原来的 50%",
            })

        return result

    async def event_impact(self, event_description: str) -> dict:
        """
        评估特定事件的影响
        
        Args:
            event_description: 事件描述
        """
        prompt = f"""请评估以下事件对加密货币市场的影响：

事件: {event_description}

请输出：
1. 影响评级 (1-10)
2. 影响方向 (利多/利空/中性)
3. 受影响的资产
4. 建议的应对措施
5. 预计持续时间

输出 JSON 格式。
"""

        result = await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.RISK_ASSESSMENT,
        )

        return result

    async def position_risk(self, positions: list) -> dict:
        """
        持仓风险分析
        
        Args:
            positions: 持仓列表
        """
        if not positions:
            return {"risk_score": 0, "message": "无持仓"}

        # 计算集中度风险
        total_value = sum(p.get("value", 0) for p in positions)
        concentrations = []
        for p in positions:
            pct = (p.get("value", 0) / total_value * 100) if total_value > 0 else 0
            concentrations.append({
                "symbol": p.get("symbol"),
                "percentage": pct,
                "risk": "high" if pct > 40 else "medium" if pct > 20 else "low",
            })

        prompt = f"""分析以下持仓的风险：

持仓详情:
{json.dumps(positions, ensure_ascii=False, indent=2)}

集中度分析:
{json.dumps(concentrations, ensure_ascii=False, indent=2)}

请评估：
1. 集中度风险
2. 杠杆风险
3. 相关性风险
4. 流动性风险
5. 综合风险评分和建议

输出 JSON 格式。
"""

        result = await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.RISK_ASSESSMENT,
        )

        result["concentrations"] = concentrations
        return result
