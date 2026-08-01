"""
新闻数据采集器
多源新闻采集 + AI 情绪分析
"""

import asyncio
import json
from datetime import datetime
from typing import Optional

import aiohttp
import feedparser
from loguru import logger

from llm_gateway.router import LLMRouter, TaskType


class NewsCollector:
    """多源新闻采集器"""

    RSS_SOURCES = {
        "coindesk": "https://www.coindesk.com/arc/outboundfeeds/rss/",
        "cointelegraph": "https://cointelegraph.com/rss",
        "bitcoin_magazine": "https://bitcoinmagazine.com/.rss/full/",
        "the_block": "https://www.theblock.co/rss.xml",
    }

    ANALYSIS_PROMPT = """分析以下金融新闻，提取关键信息并判断对市场的影响。

新闻标题: {title}
新闻摘要: {summary}
来源: {source}

输出 JSON:
{{
    "asset": "涉及的主要资产 (BTC/ETH/ALL)",
    "sentiment": "bullish/bearish/neutral",
    "impact_score": 1-10,
    "category": "政策/技术/市场/黑天鹅/机构",
    "key_points": ["要点1", "要点2"],
    "trading_signal": "buy/sell/hold/null",
    "reasoning": "判断依据"
}}
"""

    def __init__(self, llm_router: LLMRouter):
        self.llm = llm_router
        self.insights = []
        self.is_running = False

    async def start_continuous(self, interval_seconds: int = 300):
        """启动持续采集（每 5 分钟）"""
        self.is_running = True
        logger.info("📰 News collector started")

        while self.is_running:
            try:
                new_insights = await self.collect_all()
                for insight in new_insights:
                    if insight.get("impact_score", 0) >= 7:
                        logger.warning(f"🔴 High impact news: {insight.get('title')}")
                    self.insights.append(insight)

                # 保持最近 500 条
                if len(self.insights) > 500:
                    self.insights = self.insights[-250:]

            except Exception as e:
                logger.error(f"News collection error: {e}")

            await asyncio.sleep(interval_seconds)

    def stop(self):
        """停止采集"""
        self.is_running = False
        logger.info("📰 News collector stopped")

    async def collect_all(self) -> list:
        """从所有源采集新闻"""
        all_news = []
        async with aiohttp.ClientSession() as session:
            tasks = [
                self._fetch_rss(session, name, url)
                for name, url in self.RSS_SOURCES.items()
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            for result in results:
                if isinstance(result, list):
                    all_news.extend(result)

        # AI 分析每条新闻
        analyzed = []
        for news in all_news[:20]:  # 限制每批分析数量
            try:
                analysis = await self._analyze_news(news)
                analyzed.append({
                    **news,
                    "analysis": analysis,
                    "analyzed_at": datetime.now().isoformat(),
                })
            except Exception as e:
                logger.warning(f"Failed to analyze news: {e}")

        return analyzed

    async def _fetch_rss(self, session: aiohttp.ClientSession, source: str, url: str) -> list:
        """获取 RSS 源"""
        try:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status != 200:
                    return []
                text = await resp.text()
                feed = feedparser.parse(text)

                news_list = []
                for entry in feed.entries[:10]:
                    news_list.append({
                        "source": source,
                        "title": entry.get("title", ""),
                        "summary": entry.get("summary", "")[:500],
                        "url": entry.get("link", ""),
                        "published": entry.get("published", ""),
                        "collected_at": datetime.now().isoformat(),
                    })
                return news_list
        except Exception as e:
            logger.warning(f"RSS fetch failed for {source}: {e}")
            return []

    async def _analyze_news(self, news: dict) -> dict:
        """AI 分析新闻"""
        prompt = self.ANALYSIS_PROMPT.format(
            title=news.get("title", ""),
            summary=news.get("summary", ""),
            source=news.get("source", ""),
        )
        return await self.llm.call_json(
            prompt=prompt,
            task_type=TaskType.DATA_EXTRACTION,
        )

    def get_recent(self, limit: int = 20, min_impact: int = 0) -> list:
        """获取最近的新闻洞察"""
        filtered = [
            i for i in self.insights
            if i.get("analysis", {}).get("impact_score", 0) >= min_impact
        ]
        return filtered[-limit:]
