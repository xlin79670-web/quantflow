# QuantFlow 配置指南

## 一、大模型接入

### 1.1 支持的模型

| 模型 | Provider | 用途 | 获取地址 |
|------|----------|------|---------|
| **DeepSeek** | DeepSeek | 代码生成、推理 | https://platform.deepseek.com |
| **通义千问 (Qwen)** | 阿里云 | 市场分析、对话 | https://dashscope.console.aliyun.com |
| **本地模型** | Ollama/LMStudio | 离线推理、低成本 | 自建 |

### 1.2 获取 API Key

#### DeepSeek (推荐用于代码生成)

```
1. 访问 https://platform.deepseek.com
2. 注册账号
3. 进入 "API Keys" 页面
4. 点击 "创建 API Key"
5. 复制 Key (sk-xxxxxxxx)
6. 充值 (建议 $10-20 起步)
```

#### 通义千问 Qwen (推荐用于分析对话)

```
1. 访问 https://dashscope.console.aliyun.com
2. 用阿里云账号登录
3. 开通 "DashScope" 服务
4. 进入 "API-KEY 管理"
5. 创建 API Key
6. 复制 Key (sk-xxxxxxxx)
```

### 1.3 配置方式

#### 方式 A: 环境变量 (推荐)

编辑 `.env` 文件:

```env
# DeepSeek - 用于代码生成和推理
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx

# 通义千问 - 用于市场分析和对话
QWEN_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
```

#### 方式 B: 修改代码直接配置

编辑 `ai_engine/llm_gateway/router.py`:

```python
# 在 LLMRouter.__init__ 中修改
class LLMRouter:
    def __init__(self):
        self.providers = {
            "deepseek-coder": DeepSeekProvider(
                api_key="sk-xxxxxxxx",  # ← 直接填入
                model="deepseek-coder",
                base_url="https://api.deepseek.com",
            ),
            "qwen-max": QwenProvider(
                api_key="sk-xxxxxxxx",  # ← 直接填入
                model="qwen-max",
            ),
        }
```

### 1.4 更换/添加模型

#### 添加新模型 (如 GPT-4)

编辑 `ai_engine/llm_gateway/router.py`:

```python
# 1. 添加 Provider 类
class OpenAIProvider:
    def __init__(self, api_key: str, model: str):
        self.api_key = api_key
        self.model = model
        self.client = httpx.AsyncClient(timeout=60.0)

    async def call(self, prompt, system_prompt=None, temperature=0.7, max_tokens=4096, **kwargs):
        resp = await self.client.post(
            "https://api.openai.com/v1/chat/completions",
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system_prompt or ""},
                    {"role": "user", "content": prompt},
                ],
                "temperature": temperature,
                "max_tokens": max_tokens,
            },
            headers={"Authorization": f"Bearer {self.api_key}"},
        )
        resp.raise_for_status()
        return resp.json()["choices"][0]["message"]["content"]

# 2. 在 LLMRouter.__init__ 中注册
self.providers["gpt-4"] = OpenAIProvider(api_key="sk-xxx", model="gpt-4-turbo")

# 3. 修改任务路由
TASK_MODEL_MAP = {
    TaskType.CODE_GENERATION: "deepseek-coder",  # 或 "gpt-4"
    TaskType.MARKET_ANALYSIS: "gpt-4",           # 改用 GPT-4
    TaskType.CHAT: "qwen-plus",
}
```

#### 使用本地模型 (Ollama)

```bash
# 1. 安装 Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# 2. 拉取模型
ollama pull llama3.1:8b
ollama pull deepseek-coder-v2:16b

# 3. 启动服务 (默认 http://localhost:11434)
ollama serve
```

配置 `.env`:
```env
LOCAL_MODEL_PATH=http://localhost:11434
```

在 `router.py` 中添加:
```python
class OllamaProvider:
    def __init__(self, base_url: str, model: str):
        self.base_url = base_url
        self.model = model
        self.client = httpx.AsyncClient(timeout=120.0)

    async def call(self, prompt, system_prompt=None, temperature=0.7, max_tokens=4096, **kwargs):
        resp = await self.client.post(
            f"{self.base_url}/api/chat",
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system_prompt or ""},
                    {"role": "user", "content": prompt},
                ],
                "stream": False,
                "options": {"temperature": temperature},
            },
        )
        resp.raise_for_status()
        return resp.json()["message"]["content"]

# 注册
self.providers["llama-local"] = OllamaProvider(
    base_url="http://localhost:11434",
    model="llama3.1:8b",
)
```

### 1.5 模型选型建议

| 场景 | 推荐模型 | 月成本 |
|------|---------|--------|
| 代码生成 | DeepSeek-Coder | ~$5 |
| 市场分析 | Qwen-Max / GPT-4 | ~$20 |
| 日常对话 | Qwen-Plus / DeepSeek-Chat | ~$10 |
| 风险评估 | Qwen-Turbo / 本地 Llama | ~$3 |
| 离线场景 | Ollama + Llama3.1-8B | 电费 |

---

## 二、币安账号接入

### 2.1 创建 API Key

```
1. 登录 https://www.binance.com
2. 进入 [用户中心] → [API 管理]
3. 点击 [创建 API]
4. 选择 "系统生成的 API Key"
5. 完成安全验证 (邮箱/手机/谷歌)
6. 设置 API Key 权限:
   ✅ 启用读取 (Read)
   ✅ 启用现货交易 (Spot Trading)
   ❌ 禁止提币 (Enable Withdrawals) ← 重要!
7. 限制 IP (可选但推荐): 填入服务器 IP
8. 复制 API Key 和 Secret Key
   ⚠️ Secret Key 只显示一次，务必保存!
```

### 2.2 配置方式

#### 方式 A: 环境变量

```env
BINANCE_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BINANCE_SECRET_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### 方式 B: 手机端 App 输入

在 App 的 [设置] → [交易所账户] 中:
1. 点击 [添加账户]
2. 选择 "币安"
3. 输入 API Key 和 Secret Key
4. 点击 [保存]

> ⚠️ API Key 会加密存储在服务器数据库中，不会明文保存

#### 方式 C: 数据库直接配置

```sql
-- 加密存储 (需通过 API 接口，不建议直接操作数据库)
INSERT INTO exchange_accounts (id, user_id, exchange, label, api_key_enc, api_secret_enc, is_active)
VALUES (
    uuid_generate_v4(),
    '用户ID',
    'binance',
    '我的币安账户',
    '加密后的API_KEY',
    '加密后的SECRET',
    true
);
```

### 2.3 测试连接

```bash
# 测试 API 连接
curl http://localhost:8080/api/v1/exchange/ticker/BTCUSDT

# 测试账户连接 (需要 Token)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:8080/api/v1/exchange/accounts/YOUR_ACCOUNT_ID/balances
```

### 2.4 权限说明

| 权限 | 是否需要 | 说明 |
|------|---------|------|
| 读取 | ✅ 必须 | 获取行情、账户余额 |
| 现货交易 | ✅ 必须 | 下单、撤单 |
| 合约交易 | 按需 | 如果做合约需要 |
| 提币 | ❌ 禁止 | 安全考虑，永远不要开 |

---

## 三、MT4/MT5 账号接入

### 3.1 前置条件

```
1. 一个支持 EA 的 MT4/MT5 账户 (从经纪商获取)
2. 一台运行 MT4/MT5 的 VPS (推荐 Windows VPS)
3. 你的 QuantFlow MT Bridge 服务器地址
```

### 3.2 部署步骤

#### Step 1: VPS 上安装 MT4/MT5

```
1. 购买 Windows VPS (推荐: 搬瓦工、Vultr、AWS)
2. 远程桌面连接到 VPS
3. 从经纪商下载 MT4/MT5 安装包
4. 安装并登录你的交易账户
```

#### Step 2: 安装 EA

```
1. 复制 EA 文件到 MT 数据目录:
   MT4: 文件 → 打开数据文件夹 → MQL4 → Experts
   MT5: 文件 → 打开数据文件夹 → MQL5 → Experts

2. 将文件复制进去:
   MT4: mt-bridge/ea/mt4/QuantFlow_Bridge.mq4
   MT5: mt-bridge/ea/mt5/QuantFlow_Bridge.mq5

3. 在 MT 中刷新 EA 列表 (右键 Navigator → Refresh)
```

#### Step 3: 配置 EA 参数

在 MT 中双击 EA 加载到图表:

```
参数设置:
┌─────────────────────────────────────────┐
│ BridgeHost     = 你的服务器IP            │
│ BridgePort     = 9090                   │
│ TerminalID     = mt4-my-account         │
│ HeartbeatSec   = 10                     │
│ AccountSyncSec = 5                      │
│ EnableTrading  = true                   │
└─────────────────────────────────────────┘

重要: 需要勾选 "允许 DLL 导入" 和 "允许实时交易"
```

#### Step 4: 配置防火墙

```
VPS 防火墙需要放行出站端口 9090
服务器防火墙需要放行入站端口 9090
```

#### Step 5: 验证连接

```bash
# 查看已连接终端
curl http://localhost:9090/api/terminals

# 返回示例:
{
    "terminals": [
        {
            "id": "mt4-my-account",
            "platform": "mt4",
            "account": {
                "balance": 10000.00,
                "equity": 10050.00,
                "leverage": 100
            },
            "positions": 2
        }
    ]
}
```

### 3.3 MT Bridge 通信流程

```
┌──────────────┐     WebSocket      ┌──────────────┐
│   MT4/MT5    │ ◄══════════════════► │ Bridge Server│
│   EA         │    心跳/行情/订单    │   (Go)       │
└──────────────┘                     └──────┬───────┘
                                            │ REST/gRPC
                                     ┌──────┴───────┐
                                     │  Go 后端 API  │
                                     └──────────────┘
```

### 3.4 支持的经纪商

| 经纪商 | MT4 | MT5 | 说明 |
|--------|-----|-----|------|
| IC Markets | ✅ | ✅ | 推荐，低点差 |
| Pepperstone | ✅ | ✅ | 推荐 |
| OANDA | ✅ | ✅ | 美国合规 |
| XM | ✅ | ✅ | 入门友好 |
| 嘉盛 | ✅ | ✅ | 国内常用 |
| FXCM | ✅ | ❌ | - |

### 3.5 常见问题

**EA 不工作?**
```
1. 检查 MT 底部是否显示 "笑脸" (EA 已启用)
2. 检查 "工具" → "选项" → "EA交易" 是否勾选
3. 检查 Journal 日志是否有错误
4. 确认服务器地址和端口正确
```

**连接断开?**
```
1. EA 会自动重连 (每 5 秒)
2. 检查 VPS 网络是否正常
3. 检查服务器防火墙是否放行 9090 端口
4. 查看 Bridge Server 日志
```

**下单失败?**
```
1. 检查账户余额是否充足
2. 检查交易品种是否正确 (如 EURUSD vs EURUSDm)
3. 检查手数是否符合经纪商最小要求
4. 查看 MT 的 Experts 日志
```

---

## 四、安全建议

### API Key 安全
- ❌ 永远不要把 API Key 提交到 Git
- ❌ 永远不要开启提币权限
- ✅ 限制 API Key 的 IP 白名单
- ✅ 定期轮换 API Key
- ✅ 使用环境变量存储

### 交易安全
- ✅ 先用模拟账户测试
- ✅ 设置合理的止损
- ✅ 限制单笔最大仓位
- ✅ 开启风控熔断机制
- ✅ 监控异常交易告警
