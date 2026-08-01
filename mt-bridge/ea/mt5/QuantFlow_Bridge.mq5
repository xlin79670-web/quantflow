//+------------------------------------------------------------------+
//|                                          QuantFlow_Bridge.mq5    |
//|                                          QuantFlow MT5 Bridge EA |
//+------------------------------------------------------------------+
#property copyright "QuantFlow"
#property link      "https://quantflow.app"
#property version   "1.00"

// ==================== 输入参数 ====================
input string   BridgeHost     = "localhost";       // 桥接服务器地址
input int      BridgePort     = 9090;              // 桥接服务器端口
input string   TerminalID     = "mt5-demo-01";     // 终端标识
input int      HeartbeatSec   = 10;                // 心跳间隔(秒)
input int      AccountSyncSec = 5;                 // 账户同步间隔(秒)
input bool     EnableTrading  = true;              // 启用交易
input string   SymbolsList    = "EURUSD,GBPUSD,USDJPY,XAUUSD,BTCUSD"; // 订阅品种

// ==================== 全局变量 ====================
int    g_socket = INVALID_HANDLE;
bool   g_connected = false;
int    g_heartbeatTimer = 0;
int    g_accountTimer = 0;
double g_lastBid = 0;
double g_lastAsk = 0;
string g_subscribedSymbols[];

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 QuantFlow MT5 Bridge EA starting...");
   Print("   Terminal ID: ", TerminalID);
   Print("   Bridge: ", BridgeHost, ":", BridgePort);
   
   // 解析订阅品种
   StringSplit(SymbolsList, ',', g_subscribedSymbols);
   
   // 设置定时器
   EventSetMillisecondTimer(1000);
   
   // 连接
   ConnectBridge();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DisconnectBridge();
   EventKillTimer();
   Print("🛑 QuantFlow MT5 Bridge EA stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_connected) return;
   
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick))
   {
      if(tick.bid != g_lastBid || tick.ask != g_lastAsk)
      {
         SendTick(_Symbol, tick.bid, tick.ask);
         g_lastBid = tick.bid;
         g_lastAsk = tick.ask;
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_heartbeatTimer++;
   g_accountTimer++;
   
   // 重连
   if(!g_connected)
   {
      if(g_heartbeatTimer % 5 == 0)
      {
         Print("⚠️ Not connected, reconnecting...");
         ConnectBridge();
      }
      return;
   }
   
   // 心跳
   if(g_heartbeatTimer >= HeartbeatSec)
   {
      SendHeartbeat();
      g_heartbeatTimer = 0;
   }
   
   // 账户同步
   if(g_accountTimer >= AccountSyncSec)
   {
      SendAccountInfo();
      SendPositions();
      g_accountTimer = 0;
   }
   
   // 读取消息
   ReadMessages();
}

//+------------------------------------------------------------------+
//| 连接桥接服务器 (MQL5 原生 Socket)                                    |
//+------------------------------------------------------------------+
void ConnectBridge()
{
   g_socket = SocketCreate();
   if(g_socket == INVALID_HANDLE)
   {
      Print("❌ Failed to create socket: ", GetLastError());
      return;
   }
   
   if(!SocketConnect(g_socket, BridgeHost, BridgePort, 5000))
   {
      Print("❌ Connection failed: ", GetLastError());
      SocketClose(g_socket);
      g_socket = INVALID_HANDLE;
      return;
   }
   
   g_connected = true;
   Print("✅ Connected to bridge server");
   
   // 发送 ping
   string json = StringFormat(
      "{\"type\":\"ping\",\"terminal_id\":\"%s\",\"ts\":%d}",
      TerminalID, (int)TimeCurrent()
   );
   SendString(json);
   
   // 订阅品种
   SubscribeSymbols();
}

//+------------------------------------------------------------------+
//| 断开连接                                                            |
//+------------------------------------------------------------------+
void DisconnectBridge()
{
   if(g_socket != INVALID_HANDLE)
   {
      SocketClose(g_socket);
      g_socket = INVALID_HANDLE;
   }
   g_connected = false;
   Print("🔌 Disconnected");
}

//+------------------------------------------------------------------+
//| 发送心跳                                                            |
//+------------------------------------------------------------------+
void SendHeartbeat()
{
   string json = StringFormat(
      "{\"type\":\"ping\",\"terminal_id\":\"%s\",\"ts\":%d}",
      TerminalID, (int)TimeCurrent()
   );
   SendString(json);
}

//+------------------------------------------------------------------+
//| 发送 Tick                                                           |
//+------------------------------------------------------------------+
void SendTick(string symbol, double bid, double ask)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   string json = StringFormat(
      "{\"type\":\"tick\",\"terminal_id\":\"%s\",\"symbol\":\"%s\",\"bid\":%s,\"ask\":%s,\"ts\":%d}",
      TerminalID, symbol, DoubleToString(bid, digits), DoubleToString(ask, digits), (int)TimeCurrent()
   );
   SendString(json);
}

//+------------------------------------------------------------------+
//| 发送账户信息                                                        |
//+------------------------------------------------------------------+
void SendAccountInfo()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   
   string json = StringFormat(
      "{\"type\":\"account\",\"terminal_id\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"margin\":%.2f,\"free_margin\":%.2f,\"profit\":%.2f,\"leverage\":%d}",
      TerminalID, balance, equity, margin, freeMargin, profit, (int)leverage
   );
   SendString(json);
}

//+------------------------------------------------------------------+
//| 发送持仓信息                                                        |
//+------------------------------------------------------------------+
void SendPositions()
{
   string json = "{\"type\":\"positions\",\"terminal_id\":\"" + TerminalID + "\",\"data\":[";
   
   int total = PositionsTotal();
   bool first = true;
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      long type = PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double posProfit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      string comment = PositionGetString(POSITION_COMMENT);
      
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      
      if(!first) json += ",";
      first = false;
      
      json += StringFormat(
         "{\"ticket\":%d,\"symbol\":\"%s\",\"side\":\"%s\",\"lots\":%.2f,\"open_price\":%s,\"current_price\":%s,\"sl\":%s,\"tp\":%s,\"profit\":%.2f,\"swap\":%.2f,\"comment\":\"%s\"}",
         ticket, symbol, (type == POSITION_TYPE_BUY) ? "buy" : "sell", volume,
         DoubleToString(openPrice, digits), DoubleToString(currentPrice, digits),
         DoubleToString(sl, digits), DoubleToString(tp, digits),
         posProfit, swap, comment
      );
   }
   
   json += "]}";
   SendString(json);
}

//+------------------------------------------------------------------+
//| 订阅品种                                                            |
//+------------------------------------------------------------------+
void SubscribeSymbols()
{
   string json = "{\"type\":\"subscribe\",\"terminal_id\":\"" + TerminalID + "\",\"symbols\":[";
   
   for(int i = 0; i < ArraySize(g_subscribedSymbols); i++)
   {
      if(i > 0) json += ",";
      json += "\"" + g_subscribedSymbols[i] + "\"";
   }
   
   json += "]}";
   SendString(json);
}

//+------------------------------------------------------------------+
//| 读取服务器消息                                                      |
//+------------------------------------------------------------------+
void ReadMessages()
{
   if(!g_connected || g_socket == INVALID_HANDLE) return;
   
   // 检查可读字节数
   uint available = SocketIsReadable(g_socket);
   if(available == 0) return;
   
   uchar buffer[];
   ArrayResize(buffer, (int)available);
   
   int received = SocketRead(g_socket, buffer, (int)available, 100);
   if(received > 0)
   {
      string data = CharArrayToString(buffer, 0, received, CP_UTF8);
      
      // 处理可能的多条消息
      string messages[];
      int count = StringSplit(data, '\n', messages);
      for(int i = 0; i < count; i++)
      {
         if(StringLen(messages[i]) > 0)
            ProcessMessage(messages[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| 处理消息                                                            |
//+------------------------------------------------------------------+
void ProcessMessage(string data)
{
   Print("📨 Received: ", data);
   
   string type = GetJSONValue(data, "type");
   
   if(type == "pong") return;
   
   if(type == "order")
   {
      ProcessOrder(data);
   }
}

//+------------------------------------------------------------------+
//| 处理订单请求                                                        |
//+------------------------------------------------------------------+
void ProcessOrder(string data)
{
   if(!EnableTrading)
   {
      SendOrderResult(GetJSONValue(data, "order_id"), 0, "rejected", 0, "Trading disabled");
      return;
   }
   
   string action = GetJSONValue(data, "action");
   string orderID = GetJSONValue(data, "order_id");
   string symbol = GetJSONValue(data, "symbol");
   string side = GetJSONValue(data, "side");
   double lots = StringToDouble(GetJSONValue(data, "lots"));
   double price = StringToDouble(GetJSONValue(data, "price"));
   double sl = StringToDouble(GetJSONValue(data, "sl"));
   double tp = StringToDouble(GetJSONValue(data, "tp"));
   long ticket = StringToInteger(GetJSONValue(data, "ticket"));
   string comment = GetJSONValue(data, "comment");
   
   ulong resultTicket = 0;
   double fillPrice = 0;
   string error = "";
   
   if(action == "open")
   {
      // MQL5 下单
      MqlTradeRequest request = {};
      MqlTradeResult tradeResult = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = lots;
      request.deviation = 30;
      request.magic = 20260801;
      request.comment = comment;
      
      if(side == "buy")
      {
         request.type = ORDER_TYPE_BUY;
         request.price = (price > 0) ? price : SymbolInfoDouble(symbol, SYMBOL_ASK);
      }
      else
      {
         request.type = ORDER_TYPE_SELL;
         request.price = (price > 0) ? price : SymbolInfoDouble(symbol, SYMBOL_BID);
      }
      
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      request.price = NormalizeDouble(request.price, digits);
      request.sl = NormalizeDouble(sl, digits);
      request.tp = NormalizeDouble(tp, digits);
      
      if(OrderSend(request, tradeResult))
      {
         if(tradeResult.retcode == TRADE_RETCODE_DONE)
         {
            resultTicket = tradeResult.order;
            fillPrice = tradeResult.price;
            Print("✅ Order opened: ", symbol, " ", side, " ", lots, " @ ", fillPrice);
         }
         else
         {
            error = StringFormat("RetCode: %d, Comment: %s", tradeResult.retcode, tradeResult.comment);
            Print("❌ Order failed: ", error);
         }
      }
      else
      {
         error = StringFormat("OrderSend failed: %d", GetLastError());
         Print("❌ ", error);
      }
   }
   else if(action == "close")
   {
      // MQL5 平仓
      if(PositionSelectByTicket(ticket))
      {
         MqlTradeRequest request = {};
         MqlTradeResult tradeResult = {};
         
         request.action = TRADE_ACTION_DEAL;
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.deviation = 30;
         request.magic = 20260801;
         request.position = ticket;
         
         long posType = PositionGetInteger(POSITION_TYPE);
         if(posType == POSITION_TYPE_BUY)
         {
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
         }
         else
         {
            request.type = ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
         }
         
         if(OrderSend(request, tradeResult))
         {
            if(tradeResult.retcode == TRADE_RETCODE_DONE)
            {
               fillPrice = tradeResult.price;
               Print("✅ Position closed: #", ticket);
            }
            else
            {
               error = StringFormat("RetCode: %d", tradeResult.retcode);
            }
         }
      }
      else
      {
         error = "Position not found";
      }
   }
   else if(action == "modify")
   {
      // 修改止损止盈
      if(PositionSelectByTicket(ticket))
      {
         MqlTradeRequest request = {};
         MqlTradeResult tradeResult = {};
         
         request.action = TRADE_ACTION_SLTP;
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.position = ticket;
         
         int digits = (int)SymbolInfoInteger(request.symbol, SYMBOL_DIGITS);
         request.sl = NormalizeDouble(sl, digits);
         request.tp = NormalizeDouble(tp, digits);
         
         if(OrderSend(request, tradeResult))
         {
            Print("✅ Position modified: #", ticket);
         }
         else
         {
            error = StringFormat("Modify failed: %d", tradeResult.retcode);
         }
      }
   }
   
   SendOrderResult(orderID, (long)resultTicket, resultTicket > 0 ? "filled" : "error", fillPrice, error);
}

//+------------------------------------------------------------------+
//| 发送订单结果                                                        |
//+------------------------------------------------------------------+
void SendOrderResult(string orderID, long ticket, string status, double fillPrice, string error)
{
   string json = StringFormat(
      "{\"type\":\"order_result\",\"terminal_id\":\"%s\",\"order_id\":\"%s\",\"ticket\":%d,\"status\":\"%s\",\"fill_price\":%.5f,\"error\":\"%s\"}",
      TerminalID, orderID, ticket, status, fillPrice, error
   );
   SendString(json);
}

//+------------------------------------------------------------------+
//| 发送字符串                                                          |
//+------------------------------------------------------------------+
void SendString(string data)
{
   if(g_socket == INVALID_HANDLE) return;
   
   uchar buffer[];
   StringToCharArray(data, buffer, 0, WHOLE_ARRAY, CP_UTF8);
   SocketSend(g_socket, buffer, ArraySize(buffer) - 1);
}

//+------------------------------------------------------------------+
//| 简化 JSON 解析                                                      |
//+------------------------------------------------------------------+
string GetJSONValue(string json, string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return "";
   
   pos += StringLen(search);
   
   while(pos < StringLen(json) && StringGetChar(json, pos) == ' ') pos++;
   
   if(StringGetChar(json, pos) == '"')
   {
      pos++;
      int endPos = StringFind(json, "\"", pos);
      if(endPos < 0) return "";
      return StringSubstr(json, pos, endPos - pos);
   }
   
   int endPos = pos;
   while(endPos < StringLen(json))
   {
      int ch = StringGetChar(json, endPos);
      if(ch == ',' || ch == '}' || ch == ']') break;
      endPos++;
   }
   
   return StringSubstr(json, pos, endPos - pos);
}
//+------------------------------------------------------------------+
