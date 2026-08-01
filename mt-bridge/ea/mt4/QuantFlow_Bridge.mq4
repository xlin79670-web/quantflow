//+------------------------------------------------------------------+
//|                                          QuantFlow_Bridge.mq4    |
//|                                          QuantFlow MT4 Bridge EA |
//+------------------------------------------------------------------+
#property copyright "QuantFlow"
#property link      "https://quantflow.app"
#property version   "1.00"
#property strict

// ==================== 输入参数 ====================
input string   BridgeHost     = "localhost";    // 桥接服务器地址
input int      BridgePort     = 9090;           // 桥接服务器端口
input string   TerminalID     = "mt4-demo-01";  // 终端标识
input int      HeartbeatSec   = 10;             // 心跳间隔(秒)
input int      AccountSyncSec = 5;              // 账户同步间隔(秒)
input bool     EnableTrading  = true;           // 启用交易

// ==================== 全局变量 ====================
int    g_socket = -1;
bool   g_connected = false;
int    g_heartbeatTimer = 0;
int    g_accountTimer = 0;
double g_lastBid = 0;
double g_lastAsk = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 QuantFlow MT4 Bridge EA starting...");
   Print("   Terminal ID: ", TerminalID);
   Print("   Bridge: ", BridgeHost, ":", BridgePort);
   
   // 初始化定时器
   EventSetTimer(1);
   
   // 连接桥接服务器
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
   Print("🛑 QuantFlow MT4 Bridge EA stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_connected) return;
   
   double bid = MarketInfo(Symbol(), MODE_BID);
   double ask = MarketInfo(Symbol(), MODE_ASK);
   
   // 价格变化时推送 tick
   if(bid != g_lastBid || ask != g_lastAsk)
   {
      SendTick(Symbol(), bid, ask);
      g_lastBid = bid;
      g_lastAsk = ask;
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_heartbeatTimer++;
   g_accountTimer++;
   
   // 重连检查
   if(!g_connected)
   {
      if(g_heartbeatTimer % 5 == 0)
      {
         Print("⚠️ Not connected, attempting reconnect...");
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
   
   // 读取服务器消息
   ReadMessages();
}

//+------------------------------------------------------------------+
//| 连接桥接服务器                                                      |
//+------------------------------------------------------------------+
void ConnectBridge()
{
   // MQL4 使用 DLL 进行 WebSocket 连接
   // 这里使用简化的 TCP socket 实现
   // 实际生产中建议使用 WebSocket DLL (如 wininet.dll)
   
   g_socket = SocketCreate();
   if(g_socket == INVALID_HANDLE)
   {
      Print("❌ Failed to create socket");
      return;
   }
   
   if(!SocketConnect(g_socket, BridgeHost, BridgePort, 5000))
   {
      Print("❌ Failed to connect to ", BridgeHost, ":", BridgePort);
      SocketClose(g_socket);
      g_socket = -1;
      return;
   }
   
   g_connected = true;
   Print("✅ Connected to bridge server");
   
   // 发送连接消息
   string msg = BuildJSON("ping", "");
   SocketSend(g_socket, msg, StringLen(msg));
   
   // 订阅主要品种
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
      g_socket = -1;
   }
   g_connected = false;
   Print("🔌 Disconnected from bridge server");
}

//+------------------------------------------------------------------+
//| 发送心跳                                                            |
//+------------------------------------------------------------------+
void SendHeartbeat()
{
   if(!g_connected) return;
   
   string json = "{";
   json += "\"type\":\"ping\",";
   json += "\"terminal_id\":\"" + TerminalID + "\",";
   json += "\"ts\":" + IntegerToString((int)TimeCurrent());
   json += "}";
   
   SendString(json);
}

//+------------------------------------------------------------------+
//| 发送 Tick 数据                                                      |
//+------------------------------------------------------------------+
void SendTick(string symbol, double bid, double ask)
{
   if(!g_connected) return;
   
   string json = "{";
   json += "\"type\":\"tick\",";
   json += "\"terminal_id\":\"" + TerminalID + "\",";
   json += "\"symbol\":\"" + symbol + "\",";
   json += "\"bid\":" + DoubleToString(bid, (int)MarketInfo(symbol, MODE_DIGITS)) + ",";
   json += "\"ask\":" + DoubleToString(ask, (int)MarketInfo(symbol, MODE_DIGITS)) + ",";
   json += "\"ts\":" + IntegerToString((int)TimeCurrent());
   json += "}";
   
   SendString(json);
}

//+------------------------------------------------------------------+
//| 发送账户信息                                                        |
//+------------------------------------------------------------------+
void SendAccountInfo()
{
   if(!g_connected) return;
   
   string json = "{";
   json += "\"type\":\"account\",";
   json += "\"terminal_id\":\"" + TerminalID + "\",";
   json += "\"balance\":" + DoubleToString(AccountBalance(), 2) + ",";
   json += "\"equity\":" + DoubleToString(AccountEquity(), 2) + ",";
   json += "\"margin\":" + DoubleToString(AccountMargin(), 2) + ",";
   json += "\"free_margin\":" + DoubleToString(AccountFreeMargin(), 2) + ",";
   json += "\"profit\":" + DoubleToString(AccountProfit(), 2) + ",";
   json += "\"leverage\":" + IntegerToString(AccountLeverage());
   json += "}";
   
   SendString(json);
}

//+------------------------------------------------------------------+
//| 发送持仓信息                                                        |
//+------------------------------------------------------------------+
void SendPositions()
{
   if(!g_connected) return;
   
   string json = "{";
   json += "\"type\":\"positions\",";
   json += "\"terminal_id\":\"" + TerminalID + "\",";
   json += "\"data\":[";
   
   bool first = true;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() > OP_SELL) continue; // 只要市价单
      
      if(!first) json += ",";
      first = false;
      
      json += "{";
      json += "\"ticket\":" + IntegerToString(OrderTicket()) + ",";
      json += "\"symbol\":\"" + OrderSymbol() + "\",";
      json += "\"side\":\"" + (OrderType() == OP_BUY ? "buy" : "sell") + "\",";
      json += "\"lots\":" + DoubleToString(OrderLots(), 2) + ",";
      json += "\"open_price\":" + DoubleToString(OrderOpenPrice(), (int)MarketInfo(OrderSymbol(), MODE_DIGITS)) + ",";
      json += "\"current_price\":" + DoubleToString(
         OrderType() == OP_BUY ? MarketInfo(OrderSymbol(), MODE_BID) : MarketInfo(OrderSymbol(), MODE_ASK),
         (int)MarketInfo(OrderSymbol(), MODE_DIGITS)) + ",";
      json += "\"sl\":" + DoubleToString(OrderStopLoss(), (int)MarketInfo(OrderSymbol(), MODE_DIGITS)) + ",";
      json += "\"tp\":" + DoubleToString(OrderTakeProfit(), (int)MarketInfo(OrderSymbol(), MODE_DIGITS)) + ",";
      json += "\"profit\":" + DoubleToString(OrderProfit(), 2) + ",";
      json += "\"swap\":" + DoubleToString(OrderSwap(), 2) + ",";
      json += "\"comment\":\"" + OrderComment() + "\"";
      json += "}";
   }
   
   json += "]}";
   SendString(json);
}

//+------------------------------------------------------------------+
//| 订阅品种                                                            |
//+------------------------------------------------------------------+
void SubscribeSymbols()
{
   string symbols[] = {"EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "BTCUSD"};
   string json = "{";
   json += "\"type\":\"subscribe\",";
   json += "\"terminal_id\":\"" + TerminalID + "\",";
   json += "\"symbols\":[";
   
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      if(i > 0) json += ",";
      json += "\"" + symbols[i] + "\"";
   }
   
   json += "]}";
   SendString(json);
}

//+------------------------------------------------------------------+
//| 处理服务器消息                                                      |
//+------------------------------------------------------------------+
void ReadMessages()
{
   if(!g_connected || g_socket == INVALID_HANDLE) return;
   
   // 检查是否有数据可读
   if(!SocketIsReadable(g_socket)) return;
   
   string data = "";
   uchar buffer[4096];
   
   int received = SocketReceive(g_socket, buffer, 4096, 100);
   if(received > 0)
   {
      // 转换为字符串
      data = CharArrayToString(buffer, 0, received, CP_UTF8);
      ProcessMessage(data);
   }
}

//+------------------------------------------------------------------+
//| 处理单条消息                                                        |
//+------------------------------------------------------------------+
void ProcessMessage(string data)
{
   Print("📨 Received: ", data);
   
   // 解析消息类型
   string type = GetJSONValue(data, "type");
   
   if(type == "pong")
   {
      // 心跳响应，忽略
      return;
   }
   
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
   
   int result = 0;
   double fillPrice = 0;
   string error = "";
   
   if(action == "open")
   {
      // 开仓
      int cmd = (side == "buy") ? OP_BUY : OP_SELL;
      
      if(price == 0)
      {
         price = (cmd == OP_BUY) ? MarketInfo(symbol, MODE_ASK) : MarketInfo(symbol, MODE_BID);
      }
      
      int digits = (int)MarketInfo(symbol, MODE_DIGITS);
      price = NormalizeDouble(price, digits);
      sl = NormalizeDouble(sl, digits);
      tp = NormalizeDouble(tp, digits);
      
      result = OrderSend(symbol, cmd, lots, price, 30, sl, tp, comment, 0, 0, (cmd == OP_BUY) ? clrGreen : clrRed);
      
      if(result > 0)
      {
         if(OrderSelect(result, SELECT_BY_TICKET))
         {
            fillPrice = OrderOpenPrice();
         }
         Print("✅ Order opened: ", symbol, " ", side, " ", lots, " lots @ ", fillPrice);
      }
      else
      {
         error = ErrorDescription(GetLastError());
         Print("❌ Order failed: ", error);
      }
   }
   else if(action == "close")
   {
      // 平仓
      if(OrderSelect((int)ticket, SELECT_BY_TICKET))
      {
         double closePrice = (OrderType() == OP_BUY) ? 
            MarketInfo(OrderSymbol(), MODE_BID) : 
            MarketInfo(OrderSymbol(), MODE_ASK);
         
         if(OrderClose(OrderTicket(), OrderLots(), closePrice, 30, clrYellow))
         {
            fillPrice = closePrice;
            Print("✅ Position closed: ticket #", ticket);
         }
         else
         {
            error = ErrorDescription(GetLastError());
            Print("❌ Close failed: ", error);
         }
      }
      else
      {
         error = "Order not found";
      }
   }
   else if(action == "modify")
   {
      // 修改止损止盈
      if(OrderSelect((int)ticket, SELECT_BY_TICKET))
      {
         int digits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
         sl = NormalizeDouble(sl, digits);
         tp = NormalizeDouble(tp, digits);
         
         if(OrderModify(OrderTicket(), OrderOpenPrice(), sl, tp, 0, clrBlue))
         {
            Print("✅ Order modified: ticket #", ticket);
         }
         else
         {
            error = ErrorDescription(GetLastError());
         }
      }
   }
   
   // 发送结果
   SendOrderResult(orderID, result, result > 0 ? "filled" : "error", fillPrice, error);
}

//+------------------------------------------------------------------+
//| 发送订单结果                                                        |
//+------------------------------------------------------------------+
void SendOrderResult(string orderID, int ticket, string status, double fillPrice, string error)
{
   string json = "{";
   json += "\"type\":\"order_result\",";
   json += "\"terminal_id\":\"" + TerminalID + "\",";
   json += "\"order_id\":\"" + orderID + "\",";
   json += "\"ticket\":" + IntegerToString(ticket) + ",";
   json += "\"status\":\"" + status + "\",";
   json += "\"fill_price\":" + DoubleToString(fillPrice, 5) + ",";
   json += "\"error\":\"" + error + "\"";
   json += "}";
   
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
   SocketSend(g_socket, buffer, ArraySize(buffer) - 1); // -1 去掉末尾 null
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
   
   // 跳过空格
   while(pos < StringLen(json) && StringGetChar(json, pos) == ' ') pos++;
   
   // 检查是否是字符串值
   if(StringGetChar(json, pos) == '"')
   {
      pos++; // 跳过开头引号
      int endPos = StringFind(json, "\"", pos);
      if(endPos < 0) return "";
      return StringSubstr(json, pos, endPos - pos);
   }
   
   // 数值或布尔值
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
//| 构建简单 JSON                                                       |
//+------------------------------------------------------------------+
string BuildJSON(string type, string data)
{
   return "{\"type\":\"" + type + "\",\"terminal_id\":\"" + TerminalID + "\",\"ts\":" + IntegerToString((int)TimeCurrent()) + "}";
}

//+------------------------------------------------------------------+
//| Socket 辅助函数 (MQL4 兼容)                                         |
//+------------------------------------------------------------------+
int SocketCreate() { return -1; }  // MQL4 需要使用 DLL
bool SocketConnect(int sock, string host, int port, int timeout) { return false; }
void SocketClose(int sock) {}
int SocketSend(int sock, uchar &data[], int len) { return 0; }
int SocketReceive(int sock, uchar &data[], int len, int timeout) { return 0; }
bool SocketIsReadable(int sock) { return false; }
