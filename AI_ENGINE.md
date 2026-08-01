# QuantFlow AI 引擎 — 大模型驱动的智能量化系统

## 设计理念

传统量化系统是"人写规则，机器执行"。加入大模型后，系统变成：

```
人工策略 → AI 分析优化 → 自动执行 → AI 复盘学习 → 策略进化
     ↑                                              │
     └──────────────── 闭环反馈 ────────────────────┘
```

**核心能力**：
1. 🧠 **自然语言策略生成** — 用中文描述交易想法，AI 生成可执行策略代码
2. 📰 **多源情报分析** — 新闻、社交媒体、链上数据的实时语义理解
3. 🔄 **策略自进化** — AI 分析交易结果，自动调整参数、淘汰劣策略、生成新变体
4. 💬 **AI 交易助手** — 对话式交互，随时问"为什么亏了""市场怎么了"
5. 🎯 **风险预判** — 基于宏观事件和市场结构的风险预警

---

## 系统架构（AI 层）

```
┌─────────────────────────────────────────────────────────────────┐
│                        移动端 (Flutter)                          │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │ AI 对话界面   │ │ 策略建议卡片  │ │ 市场情绪仪表盘           │ │
│  └──────┬───────┘ └──────┬───────┘ └──────────┬───────────────┘ │
│         └────────────────┼────────────────────┘                 │
└──────────────────────────┼──────────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────────┐
│                    AI 编排层 (Go + Python)                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  AI Orchestrator (Go)                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │   │
│  │  │ 意图路由  │ │ 上下文   │ │ 结果聚合  │ │ 安全过滤    │  │   │
│  │  │ & 分发   │ │ 管理器   │ │ & 格式化  │ │ & 审计     │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────────┘  │   │
│  └──────────────────────────┬───────────────────────────────┘   │
│                             │                                    │
│  ┌──────────────────────────┼───────────────────────────────┐   │
│  │              AI Agent 层 (Python)                         │   │
│  │                                                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │   │
│  │  │ 📝 策略生成  │  │ 📊 市场分析  │  │ 🔄 策略进化器   │  │   │
│  │  │   Agent     │  │   Agent     │  │    Agent        │  │   │
│  │  │             │  │             │  │                 │  │   │
│  │  │ • NL→Code   │  │ • 新闻摘要   │  │ • 参数优化      │  │   │
│  │  │ • 策略模板   │  │ • 情绪分析   │  │ • 策略变异      │  │   │
│  │  │ • 代码审查   │  │ • 链上分析   │  │ • A/B 测试      │  │   │
│  │  │ • 回测验证   │  │ • 宏观解读   │  │ • 淘汰/进化     │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘  │   │
│  │         │               │                   │            │   │
│  │  ┌──────┴───────────────┴───────────────────┴────────┐   │   │
│  │  │              LLM Gateway (统一接口)                │   │   │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │   │   │
│  │  │  │ DeepSeek │ │ Qwen     │ │ 本地模型          │   │   │   │
│  │  │  │ (推理)   │ │ (长文本)  │ │ (Llama/微调)     │   │   │   │
│  │  │  └──────────┘ └──────────┘ └──────────────────┘   │   │   │
│  │  └───────────────────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              数据采集层                                    │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │   │
│  │  │ 新闻爬虫  │ │ 社交媒体  │ │ 链上数据  │ │ 宏观经济    │  │   │
│  │  │ (RSS/    │ │ (Twitter │ │ (Glass-  │ │ (FRED/     │  │   │
│  │  │  新闻站) │ │  Reddit) │ │  node)   │ │  经济日历)  │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 五大 AI Agent 详解

### Agent 1: 📝 策略生成器 (Strategy Generator)

**功能**：用户用自然语言描述交易想法 → AI 生成可运行的策略代码

**工作流**：
```
用户输入: "当 BTC 的 RSI 低于 30 且成交量放大 2 倍时买入，RSI 超过 70 卖出，止损 5%"
        │
        ▼
┌─────────────────────────────────┐
│  Step 1: 意图解析               │
│  • 提取: 标的=BTC, 买入条件=    │
│    RSI<30+量放大, 卖出=RSI>70   │
│  • 风控: 止损=5%                │
├─────────────────────────────────┤
│  Step 2: 策略代码生成           │
│  • 选择模板: RSI + Volume       │
│  • 填充参数                     │
│  • 生成 Python 策略代码         │
├─────────────────────────────────┤
│  Step 3: 自动回测验证           │
│  • 用近 90 天数据回测           │
│  • 输出: 收益率、最大回撤、胜率 │
├─────────────────────────────────┤
│  Step 4: 呈现 + 确认            │
│  • 展示代码 + 回测结果          │
│  • 用户确认/调整 → 部署         │
└─────────────────────────────────┘
```

**LLM 选型**：DeepSeek-Coder / Qwen2.5-Coder（代码生成能力强）

**关键技术**：
- Few-shot prompting：内置 50+ 策略模板作为示例
- 代码沙箱：生成的代码在隔离环境中执行回测
- 自动修复：回测报错时 LLM 自动分析错误并修正代码

---

### Agent 2: 📊 市场分析师 (Market Analyst)

**功能**：实时采集多源信息，生成市场洞察和交易信号

**数据源 & 分析维度**：

| 数据源 | 分析内容 | 更新频率 |
|--------|---------|---------|
| 新闻网站 (CoinDesk, 金十) | 重大事件识别、利好利空判断 | 实时 |
| Twitter/X KOL | 市场情绪、热点叙事 | 5 分钟 |
| Reddit / 论坛 | 散户情绪、恐慌指数 | 15 分钟 |
| 链上数据 | 大额转账、交易所净流入流出 | 实时 |
| 经济日历 | CPI、FOMC、非农等宏观事件 | 日历触发 |
| 恐惧贪婪指数 | 综合市场情绪 | 每小时 |

**输出示例**：
```
📊 市场快报 — 2026-08-01 15:30

🔴 BTC $62,450 (-2.3%)

📰 关键事件：
• 美联储 Powell 讲话偏鹰，暗示 9 月不降息
• 币安新增 BTC/ETH 现货交易对
• 链上：巨鲸地址过去 24h 净增持 3,200 BTC

😰 情绪：恐慌 (恐惧指数 28)
💡 AI 判断：短期承压，但链上增持信号偏多头
   建议：观望为主，若跌破 $61,000 触发止损

📈 你的策略状态：
• 均线交叉策略：持仓中，浮亏 -1.2%
• RSI 策略：空仓，等待信号
```

**LLM 选型**：Qwen2.5-72B（长文本理解 + 中文能力强）或 DeepSeek-V3

---

### Agent 3: 🔄 策略进化器 (Strategy Evolver) ⭐ 核心差异化

**功能**：AI 自动分析策略表现，迭代优化参数，生成进化版本

**进化周期**：
```
┌──────────────────────────────────────────────────────┐
│                    策略进化闭环                        │
│                                                       │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐          │
│  │ 运行策略  │───▶│ 收集数据  │───▶│ AI 分析  │          │
│  │ (7天)    │    │ 交易记录  │    │ 表现归因  │          │
│  └─────────┘    │ 市场环境  │    │ 优劣诊断  │          │
│                 └─────────┘    └────┬────┘          │
│                                     │                │
│                                     ▼                │
│                              ┌─────────┐             │
│                              │ 生成变体  │             │
│                              │ • 参数调整 │             │
│                              │ • 逻辑微调 │             │
│                              │ • 新策略   │             │
│                              └────┬────┘             │
│                                   │                  │
│                                   ▼                  │
│                            ┌──────────┐              │
│                            │ 模拟回测  │              │
│                            │ 变体 vs 原│              │
│                            └────┬─────┘              │
│                                 │                    │
│                          ┌──────┴──────┐             │
│                          ▼             ▼             │
│                    ┌──────────┐  ┌──────────┐       │
│                    │ 变体更优  │  │ 原策略更优│       │
│                    │ → 推荐替换│  │ → 保留    │       │
│                    └──────────┘  └──────────┘       │
└──────────────────────────────────────────────────────┘
```

**分析维度**：
```
AI 复盘报告示例：

策略: 均线交叉 (BTC/USDT, 1h)
运行周期: 2026-07-25 ~ 2026-08-01

📊 表现总结:
• 总收益: +3.2% (基准 BTC: -1.5%)
• 交易次数: 12 次 | 胜率: 58% | 盈亏比: 1.8:1
• 最大回撤: -4.1%

🔍 AI 归因分析:
1. 盈利交易集中在 7/27-7/28 的震荡行情
2. 亏损主要来自 7/31 的假突破（3 笔连续止损）
3. 当前快线周期(5)在高波动时信号过于频繁

💡 优化建议:
• 方案 A: 快线周期 5→8，减少假信号（回测收益 +1.5%）
• 方案 B: 增加 ATR 过滤器，波动率 > 2% 时暂停交易
• 方案 C: 结合 RSI 确认信号，RSI > 50 时才做多

🎯 推荐: 方案 B（风险调整后收益最优）
是否应用优化？[是] [否] [查看详细回测]
```

**核心技术**：
- **贝叶斯优化**：参数空间搜索，比网格搜索高效 10x
- **遗传算法**：策略逻辑变异 + 交叉 + 选择
- **LLM 归因**：用大模型分析"为什么亏了"，比纯统计更有洞察
- **A/B 测试框架**：新旧策略同时运行，用统计显著性决定替换

---

### Agent 4: 💬 AI 交易助手 (Trading Copilot)

**功能**：对话式交互，回答交易相关问题，执行操作

**对话示例**：
```
用户: 我的策略今天表现怎么样？

AI: 📊 今日策略报告：
    • 均线交叉：触发 2 次信号，1 胜 1 负，净收益 +0.8%
    • RSI 策略：未触发信号，当前持仓 BTC 均价 $62,100
    • 总账户：$10,320 (+$180 今日)

用户: 为什么均线策略刚才亏了？

AI: 🔍 分析刚才的亏损交易：
    • 时间: 14:32 买入 BTC @ $62,800
    • 信号: 5 均线上穿 20 均线
    • 结果: 14:58 止损卖出 @ $61,900 (-1.4%)
    
    原因: 这是一个"假金叉"——价格在阻力位附近出现
    短暂反弹但没有量能支撑。成交量比前 5 根 K 线
    平均量低 30%。
    
    💡 建议: 增加成交量确认条件，金叉时成交量需
    高于 20 周期均量的 1.2 倍。是否自动应用？

用户: 帮我把止损从 3% 改成 2%

AI: ✅ 已更新「均线交叉」策略的止损参数：
    • 止损: 3% → 2%
    • 生效时间: 下一次开仓
    • ⚠️ 注意: 更紧的止损可能增加被扫损的频率
    是否同步调整止盈比例？当前为 6% (3:1 盈亏比)

用户: 明天有美联储讲话，要不要暂停策略？

AI: 📅 检测到高影响事件：
    • 2026-08-02 02:00 (北京时间) — FOMC 利率决议
    • 历史统计: FOMC 日 BTC 平均波动 ±4.2%
    
    🤖 建议方案：
    1. 暂停所有策略，FOMC 后 2 小时恢复（保守）
    2. 保留策略但收紧止损至 1.5%（平衡）
    3. 仅暂停高杠杆合约策略（激进）
    
    推荐方案 1。是否执行？
```

**LLM 选型**：DeepSeek-V3 / Qwen2.5（对话 + 工具调用能力）

---

### Agent 5: 🎯 风险预判器 (Risk Predictor)

**功能**：基于宏观事件和市场结构，提前预警风险

**预警维度**：
```
┌─────────────────────────────────────────────┐
│              风险评分矩阵                     │
├──────────────┬──────────┬───────────────────┤
│ 风险因子     │ 当前状态  │ 风险等级           │
├──────────────┼──────────┼───────────────────┤
│ 宏观事件     │ FOMC 明日 │ 🔴 高             │
│ 资金费率     │ +0.03%   │ 🟡 中（偏多头拥挤）│
│ 交易所净流入  │ +5000BTC │ 🔴 高（潜在抛压）  │
│ 恐惧贪婪指数  │ 72       │ 🟡 中（偏贪婪）    │
│ 链上活跃度   │ 正常     │ 🟢 低             │
│ 大额转账     │ 3笔>1000 │ 🟡 中（需关注）    │
├──────────────┼──────────┼───────────────────┤
│ 综合风险评分  │          │ 🟡 6.5/10         │
│ 建议操作     │          │ 减仓 30% 或暂停   │
└──────────────┴──────────┴───────────────────┘
```

**自动响应规则**：
```
IF 风险评分 > 8 → 自动暂停所有策略 + 推送通知
IF 风险评分 > 6 → 收紧止损 50% + 推送建议
IF 检测到黑天鹅 (暴跌>10%/交易所宕机) → 立即平仓 + 推送
```

---

## LLM 选型策略

### 多模型混合架构

```
┌─────────────────────────────────────────────────┐
│                LLM Gateway                       │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  路由策略 (按任务类型选择模型)               │  │
│  │                                             │  │
│  │  代码生成  → DeepSeek-Coder-V2 (6.7B)      │  │
│  │  市场分析  → Qwen2.5-72B / DeepSeek-V3     │  │
│  │  对话交互  → Qwen2.5-14B (低延迟)          │  │
│  │  风险评估  → 本地微调模型 (Llama-3.1-8B)   │  │
│  │  数据提取  → Qwen2.5-7B (结构化输出)       │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  成本控制                                   │  │
│  │  • 简单任务 → 小模型 (低延迟低成本)         │  │
│  │  • 复杂分析 → 大模型 (高质量)               │  │
│  │  • 批量任务 → 异步队列 + 限频               │  │
│  │  • 缓存层: 相似查询直接返回缓存结果         │  │
│  └────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### 推荐模型清单

| 用途 | 模型 | 部署方式 | 月成本估算 |
|------|------|---------|-----------|
| 代码生成 | DeepSeek-Coder-V2 | API (DeepSeek) | ~$15 |
| 市场分析 | Qwen2.5-72B | API (通义) | ~$30 |
| 对话助手 | Qwen2.5-14B | 自建 (4090) 或 API | ~$20 |
| 风险评估 | Llama-3.1-8B (微调) | 自建 (本地) | 电费 |
| 结构化提取 | Qwen2.5-7B | 自建 (本地) | 电费 |

**月总成本估算**: API 调用 ~$65 + 自建 GPU 服务器 ~$50 = **~$115/月**

---

## 策略进化的技术实现

### 参数优化：贝叶斯优化

```python
# engine/optimizer/bayesian.py

from skopt import gp_minimize
from skopt.space import Integer, Real

class StrategyOptimizer:
    """贝叶斯优化策略参数"""
    
    def __init__(self, strategy_class, data, metric='sharpe'):
        self.strategy = strategy_class
        self.data = data
        self.metric = metric
    
    def objective(self, params):
        """目标函数：负夏普比率（最小化）"""
        strategy = self.strategy(*params)
        result = strategy.backtest(self.data)
        return -result[self.metric]  # 负号因为 gp_minimize 求最小值
    
    def optimize(self, n_calls=50):
        """运行优化"""
        space = [
            Integer(5, 50, name='fast_period'),     # 快线周期
            Integer(20, 200, name='slow_period'),    # 慢线周期
            Real(0.01, 0.1, name='stop_loss'),       # 止损比例
            Real(0.5, 1.0, name='position_size'),    # 仓位比例
        ]
        
        result = gp_minimize(
            self.objective,
            space,
            n_calls=n_calls,
            random_state=42,
            acq_func='EI'  # Expected Improvement
        )
        
        return {
            'best_params': dict(zip(
                ['fast_period', 'slow_period', 'stop_loss', 'position_size'],
                result.x
            )),
            'best_sharpe': -result.fun,
            'all_trials': result.func_vals.tolist()
        }
```

### 策略变异：LLM 驱动的逻辑进化

```python
# engine/evolver/llm_mutator.py

class StrategyMutator:
    """使用 LLM 对策略逻辑进行智能变异"""
    
    MUTATION_PROMPT = """
    你是一个量化交易策略优化专家。以下是一个交易策略的代码和它最近的表现。
    
    ## 当前策略
    ```python
    {strategy_code}
    ```
    
    ## 近期表现
    - 总收益: {total_return}%
    - 胜率: {win_rate}%
    - 最大回撤: {max_drawdown}%
    - 交易次数: {trade_count}
    
    ## 失败交易分析
    {losing_trades_analysis}
    
    请提出 3 个具体的策略改进方案，每个方案修改策略的一个方面。
    要求：
    1. 每个方案只改变一个变量/条件
    2. 给出修改后的完整代码
    3. 解释修改的逻辑依据
    
    输出 JSON 格式:
    [
      {
        "name": "改进方案名称",
        "description": "修改说明",
        "code": "完整策略代码",
        "expected_impact": "预期效果"
      }
    ]
    """
    
    async def mutate(self, strategy, performance_report):
        """生成策略变异体"""
        prompt = self.MUTATION_PROMPT.format(
            strategy_code=strategy.source_code,
            total_return=performance_report.total_return,
            win_rate=performance_report.win_rate,
            max_drawdown=performance_report.max_drawdown,
            trade_count=performance_report.trade_count,
            losing_trades_analysis=performance_report.losing_analysis
        )
        
        variants = await self.llm_gateway.call(
            model='deepseek-coder',
            prompt=prompt,
            response_format='json'
        )
        
        return [StrategyVariant.from_dict(v) for v in variants]
```

### A/B 测试框架

```python
# engine/evolver/ab_test.py

import numpy as np
from scipy import stats

class ABTestManager:
    """策略 A/B 测试管理器"""
    
    def __init__(self, confidence_level=0.95):
        self.confidence_level = confidence_level
        self.tests = {}
    
    def start_test(self, test_id, strategy_a, strategy_b, 
                   allocation=0.5, min_trades=30):
        """
        启动 A/B 测试
        allocation: 策略 A 分配的资金比例
        """
        self.tests[test_id] = {
            'strategy_a': strategy_a,
            'strategy_b': strategy_b,
            'allocation': allocation,
            'min_trades': min_trades,
            'returns_a': [],
            'returns_b': [],
            'start_time': datetime.now(),
            'status': 'running'
        }
    
    def record_trade(self, test_id, strategy_id, trade_return):
        """记录交易结果"""
        test = self.tests[test_id]
        if strategy_id == 'A':
            test['returns_a'].append(trade_return)
        else:
            test['returns_b'].append(trade_return)
        
        # 检查是否可以得出结论
        if self._sufficient_data(test):
            self._evaluate(test_id)
    
    def _evaluate(self, test_id):
        """统计检验：B 是否显著优于 A"""
        test = self.tests[test_id]
        returns_a = np.array(test['returns_a'])
        returns_b = np.array(test['returns_b'])
        
        # Welch's t-test (不假设等方差)
        t_stat, p_value = stats.ttest_ind(returns_b, returns_a, 
                                           equal_var=False)
        
        # 效应量 (Cohen's d)
        pooled_std = np.sqrt(
            (returns_a.std()**2 + returns_b.std()**2) / 2
        )
        cohens_d = (returns_b.mean() - returns_a.mean()) / pooled_std
        
        if p_value < (1 - self.confidence_level):
            if returns_b.mean() > returns_a.mean():
                test['status'] = 'B_wins'
                test['recommendation'] = '推荐替换为策略 B'
            else:
                test['status'] = 'A_wins'
                test['recommendation'] = '保留策略 A'
            test['p_value'] = p_value
            test['effect_size'] = cohens_d
```

---

## 数据采集模块

### 新闻 & 社交媒体采集

```python
# engine/data_collector/news_collector.py

class NewsCollector:
    """多源新闻采集器"""
    
    SOURCES = {
        'coindesk': 'https://www.coindesk.com/arc/outboundfeeds/rss/',
        'cointelegraph': 'https://cointelegraph.com/rss',
        'jin10': 'https://www.jin10.com/flash_newest.js',  # 金十快讯
        'mytoken': 'https://api.mytoken.org/ticker/news',
    }
    
    ANALYSIS_PROMPT = """
    分析以下金融新闻，提取关键信息：
    
    新闻标题: {title}
    新闻内容: {content}
    
    请输出 JSON:
    {{
        "asset": "涉及资产 (BTC/ETH/...)",
        "sentiment": "bullish/bearish/neutral",
        "impact_score": 1-10,
        "category": "政策/技术/市场/黑天鹅",
        "key_points": ["要点1", "要点2"],
        "trading_signal": "buy/sell/hold/null",
        "reasoning": "判断依据"
    }}
    """
    
    async def collect_and_analyze(self):
        """采集并分析新闻"""
        articles = await self._fetch_all_sources()
        
        for article in articles:
            # LLM 分析
            analysis = await self.llm_gateway.call(
                model='qwen2.5-14b',
                prompt=self.ANALYSIS_PROMPT.format(**article)
            )
            
            # 高影响新闻立即推送
            if analysis['impact_score'] >= 7:
                await self.notify_service.push_alert(
                    title=f"📰 重大新闻",
                    body=f"{analysis['asset']}: {article['title']}",
                    data=analysis
                )
            
            # 存储到数据库
            await self.db.save_news_analysis(article, analysis)
```

### 链上数据监控

```python
# engine/data_collector/onchain_collector.py

class OnchainCollector:
    """链上数据监控"""
    
    MONITOR_RULES = {
        'whale_transfer': {
            'threshold_btc': 1000,
            'threshold_eth': 10000,
            'alert': True
        },
        'exchange_flow': {
            'net_inflow_threshold': 5000,  # BTC
            'alert': True
        },
        'stablecoin_mint': {
            'threshold_usdt': 100_000_000,  # 1亿 USDT
            'alert': True
        }
    }
    
    async def monitor_whale_activity(self):
        """监控巨鲸活动"""
        while True:
            transfers = await self.blockchain_api.get_large_transfers()
            
            for tx in transfers:
                if tx.amount >= self.MONITOR_RULES['whale_transfer']['threshold_btc']:
                    # LLM 分析转账意图
                    analysis = await self._analyze_transfer(tx)
                    
                    await self.notify_service.push_alert(
                        title=f"🐋 巨鲸转账",
                        body=f"{tx.amount} BTC: {tx.from_label} → {tx.to_label}",
                        data={'analysis': analysis, 'tx': tx}
                    )
            
            await asyncio.sleep(60)  # 每分钟检查
```

---

## 更新后的项目结构

```
quant-trading-app/
├── mobile/                    # Flutter 移动端
│   ├── lib/
│   │   ├── features/
│   │   │   ├── ai_chat/       # AI 对话界面 ⭐ 新增
│   │   │   ├── ai_insight/    # AI 市场洞察 ⭐ 新增
│   │   │   ├── strategy/
│   │   │   ├── trading/
│   │   │   ├── dashboard/
│   │   │   └── analytics/
│   │   └── ...
│
├── backend/                   # Go 后端
│   ├── internal/
│   │   ├── ai/                # AI 编排层 ⭐ 新增
│   │   │   ├── orchestrator.go
│   │   │   ├── router.go
│   │   │   └── context.go
│   │   ├── exchange/
│   │   ├── engine/
│   │   ├── risk/
│   │   └── notify/
│
├── ai_engine/                 # Python AI 引擎 ⭐ 新增
│   ├── agents/
│   │   ├── strategy_generator.py   # 策略生成 Agent
│   │   ├── market_analyst.py       # 市场分析 Agent
│   │   ├── strategy_evolver.py     # 策略进化 Agent
│   │   ├── trading_copilot.py      # 交易助手 Agent
│   │   └── risk_predictor.py       # 风险预判 Agent
│   ├── llm_gateway/
│   │   ├── router.py               # 模型路由
│   │   ├── providers/
│   │   │   ├── deepseek.py
│   │   │   ├── qwen.py
│   │   │   └── local.py
│   │   └── cache.py                # 结果缓存
│   ├── data_collector/
│   │   ├── news_collector.py       # 新闻采集
│   │   ├── social_collector.py     # 社交媒体
│   │   ├── onchain_collector.py    # 链上数据
│   │   └── macro_collector.py      # 宏观数据
│   ├── optimizer/
│   │   ├── bayesian.py             # 贝叶斯优化
│   │   ├── genetic.py              # 遗传算法
│   │   └── ab_test.py              # A/B 测试
│   ├── prompts/                    # Prompt 模板
│   │   ├── strategy_gen.py
│   │   ├── market_analysis.py
│   │   └── risk_assessment.py
│   └── requirements.txt
│
├── engine/                    # 策略执行引擎 (原有)
├── mt-bridge/                 # MT4/5 桥接 (原有)
├── docker-compose.yml
└── README.md
```

---

## 更新后的开发路线图

### Phase 1 — MVP (6-8 周)
- [ ] 用户注册/登录
- [ ] 币安 API 接入（现货）
- [ ] 2 个内置策略 + 基础回测
- [ ] **AI 交易助手（基础对话）** ⭐
- [ ] **AI 市场快报（新闻摘要）** ⭐
- [ ] 推送通知

### Phase 2 — 智能化 (6 周)
- [ ] **策略自动生成（NL → Code）** ⭐
- [ ] **策略参数贝叶斯优化** ⭐
- [ ] **多源数据采集（新闻+社交+链上）** ⭐
- [ ] MT4/5 桥接接入
- [ ] 高级风控模块

### Phase 3 — 进化 (6 周)
- [ ] **策略进化器（LLM 变异 + A/B 测试）** ⭐
- [ ] **风险预判系统** ⭐
- [ ] **策略市场（AI 推荐）** ⭐
- [ ] 合约交易支持
- [ ] Web 端管理后台

### Phase 4 — 生态 (4 周)
- [ ] 微调本地模型（策略领域）
- [ ] 跟单系统 + AI 筛选
- [ ] 社区策略分享
- [ ] 多语言支持
