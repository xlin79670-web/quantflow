"""
市场分析师 Agent
多源情报分析：新闻、社交媒体、链上数据
"""

import json
from datetime import datetime
from typing import Optional

from llm_gateway.router import LLMRouter, TaskType


class MarketAnalystAgent:
    """市场分析师 - AI 驱动的多源情报分析"""

    SYSTEM_PROMPT = """你是一个资深的加密货币/金融市场分析师。你的任务是综合分析多源数据，提供客观、数据驱动的市场洞察。

分析框架：
1. 技术面：价格走势、关键支撑阻力位、技术指标信号
2. 基本面：项目进展、合作伙伴、代币经济学
3. 情绪面：社交媒体情绪、恐惧贪婪指数、资金费率
4. 宏观面：美联储政策、监管动态、地缘政治
5. 链上数据：巨鲸活动、交易所流入流出、活跃地址

输出要求：
- 用数据说话，避免主观臆断
- 明确区分"事实"和"分析推断"
- 给出具体的交易建议和风险提示
- 使用 emoji 让报告更生动
"""

    def __init__(self, llm_router: LLMRouter):
        self.llm = llm_router
        self.insights_cache = []

    async def analyze(
        self,
        symbol: str = "BTCUSDT",
        analysis_type: str = "comprehensive",
    ) -> dict:
        """
        综合市场分析
        
        Args:
            symbol: 交易对
            analysis_type: 分析类型 (comprehensive, technical, sentiment)
        """
        # 获取市场数据（实际项目中从交易所和数据源获取）
        market_data = await self._gather_market_data(symbol)

        prompt = f"""请对 {symbol} 进行全面的市场分析：

## 当前行情
- 价格: ${market_data.get('price', 'N/A')}
- 24h 涨跌: {market_data.get('change_24h', 'N/A')}%
- 24h 成交量: ${market_data.get('volume_24h', 'N/A')}
- 24h 最高: ${market_data.get('high_24h', 'N/A')}
- 24h 最低: ${market_data.get('low_24h', 'N/A')}

## 近期新闻
{self._format_news(market_data.get('news', []))}

## 链上数据
{self._format_onchain(market_data.get('onchain', {}))}

## 市场情绪
- 恐惧贪婪指数: {market_data.get('fear_greed', 'N/A')}
- 资金费率: {market_data.get('funding_rate', 'N/A')}%

请输出 JSON 格式的分析报告：
{{
    "symbol": "BTCUSDT",
    "timestamp": "ISO 时间",
    "price_summary": {{
        "current": 0,
        "change_24h": 0,
        "trend": "up|down|sideways",
        "key_levels": {{
            "resistance": [0, 0],
            "support": [0, 0]
        }}
    }},
    "sentiment": {{
        "overall": "bullish|bearish|neutral",
        "score": 1-10,
        "fear_greed": 0,
        "social_sentiment": "positive|negative|neutral"
    }},
    "analysis": {{
        "technical": "技术面分析",
        "fundamental": "基本面分析",
        "macro": "宏观面分析",
        "onchain": "链上数据分析"
    }},
    "trading_signal": {{
        "action": "buy|sell|hold",
        "confidence": 1-10,
        "entry_zone": [0, 0],
        "stop_loss": 0,
        "take_profit": [0, 0],
        "risk_reward": "1:X"
    }},
    "risk_factors": ["风险1", "风险2"],
    "summary": "一句话总结"
}}
"""

        result = await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.MARKET_ANALYSIS,
            system_prompt=self.SYSTEM_PROMPT,
        )

        # 缓存分析结果
        self.insights_cache.append(result)
        if len(self.insights_cache) > 100:
            self.insights_cache = self.insights_cache[-50:]

        return result

    async def get_recent_insights(self, symbol: str, limit: int = 20) -> list:
        """获取最近的市场洞察"""
        return self.insights_cache[-limit:]

    async def quick_sentiment(self, symbol: str) -> dict:
        """快速情绪分析（低延迟）"""
        prompt = f"用一句话分析 {symbol} 当前的市场情绪，给出 sentiment (bullish/bearish/neutral) 和 score (1-10)"
        result = await self.llm.call(
            prompt=prompt,
            task_type=TaskType.CHAT,
            max_tokens=200,
        )
        return {"raw_analysis": result}

    async def _gather_market_data(self, symbol: str) -> dict:
        """采集市场数据（实际项目中从多个数据源获取）"""
        # TODO: 接入真实数据源
        return {
            "price": 62450,
            "change_24h": -2.3,
            "volume_24h": 28500000000,
            "high_24h": 64200,
            "low_24h": 61800,
            "fear_greed": 28,
            "funding_rate": 0.03,
            "news": [
                {"title": "美联储 Powell 讲话偏鹰", "impact": "high", "sentiment": "bearish"},
                {"title": "币安新增交易对", "impact": "low", "sentiment": "neutral"},
                {"title": "巨鲸增持 3200 BTC", "impact": "medium", "sentiment": "bullish"},
            ],
            "onchain": {
                "exchange_net_flow": "+5000 BTC",
                "whale_activity": "3 笔 > 1000 BTC",
                "active_addresses": "正常",
            },
        }

    def _format_news(self, news: list) -> str:
        if not news:
            return "暂无新闻数据"
        return "\n".join([
            f"- [{n.get('impact', 'N/A')}] {n.get('title', '')} ({n.get('sentiment', 'N/A')})"
            for n in news
        ])

    def _format_onchain(self, onchain: dict) -> str:
        if not onchain:
            return "暂无链上数据"
        return "\n".join([f"- {k}: {v}" for k, v in onchain.items()])
