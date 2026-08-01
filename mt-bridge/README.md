# QuantFlow MT4/MT5 桥接方案

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                        手机 App                              │
│                    (QuantFlow Mobile)                        │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS
┌──────────────────────────┼──────────────────────────────────┐
│                    Go 后端 API                                │
│                    (QuantFlow Backend)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │ gRPC / REST
┌──────────────────────────┼──────────────────────────────────┐
│                    MT Bridge Server (Go)                     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ WebSocket    │  │ 会话管理      │  │ 订单路由         │  │
│  │ Server       │  │ (连接池)      │  │ (MT4/MT5 分发)   │  │
│  └──────┬───────┘  └──────────────┘  └──────────────────┘  │
└─────────┼────────────────────────────────────────────────────┘
          │ WebSocket (wss://)
          │
    ┌─────┴─────────────────────────────────┐
    │                                       │
    ▼                                       ▼
┌──────────────┐                    ┌──────────────┐
│  MT4 终端    │                    │  MT5 终端    │
│  (VPS)       │                    │  (VPS)       │
│              │                    │              │
│  ┌────────┐  │                    │  ┌────────┐  │
│  │   EA   │  │                    │  │   EA   │  │
│  │(MQL4)  │  │                    │  │(MQL5)  │  │
│  └────────┘  │                    │  └────────┘  │
└──────────────┘                    └──────────────┘
```

## 为什么用 WebSocket 而不是 gRPC？

MT4/MT5 的 MQL 语言**不支持原生 gRPC**，但有内置的 WebSocket 能力（通过 DLL 或原生 Socket）。
因此架构为：

- **MT ↔ Bridge Server**: WebSocket（JSON 协议）
- **Bridge Server ↔ Backend**: gRPC / REST

## 通信协议

### WebSocket JSON 消息格式

```json
// 心跳
{"type": "ping", "terminal_id": "mt4-demo-01", "ts": 1690000000}

// 订阅行情
{"type": "subscribe", "symbols": ["EURUSD", "GBPUSD"]}

// 行情推送 (Server → EA)
{
    "type": "tick",
    "symbol": "EURUSD",
    "bid": 1.08520,
    "ask": 1.08540,
    "time": 1690000000
}

// 下单请求 (Server → EA)
{
    "type": "order",
    "action": "open",
    "order_id": "uuid-xxx",
    "symbol": "EURUSD",
    "side": "buy",
    "lots": 0.1,
    "price": 0,          // 0 = market price
    "sl": 1.08000,        // stop loss
    "tp": 1.09000,        // take profit
    "comment": "QuantFlow-MACross"
}

// 下单结果 (EA → Server)
{
    "type": "order_result",
    "order_id": "uuid-xxx",
    "ticket": 12345678,
    "status": "filled",   // filled, rejected, error
    "fill_price": 1.08525,
    "error": ""
}

// 平仓请求 (Server → EA)
{
    "type": "order",
    "action": "close",
    "order_id": "uuid-yyy",
    "ticket": 12345678
}

// 账户信息 (EA → Server, 定时上报)
{
    "type": "account",
    "balance": 10000.00,
    "equity": 10050.00,
    "margin": 500.00,
    "free_margin": 9550.00,
    "profit": 50.00,
    "leverage": 100
}

// 持仓信息 (EA → Server, 定时上报)
{
    "type": "positions",
    "data": [
        {
            "ticket": 12345678,
            "symbol": "EURUSD",
            "side": "buy",
            "lots": 0.1,
            "open_price": 1.08525,
            "current_price": 1.08600,
            "sl": 1.08000,
            "tp": 1.09000,
            "profit": 7.50,
            "swap": -0.12,
            "comment": "QuantFlow-MACross"
        }
    ]
}
```
