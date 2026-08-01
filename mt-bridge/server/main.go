package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

// ==================== 消息协议 ====================

type Message struct {
	Type       string      `json:"type"`
	TerminalID string      `json:"terminal_id,omitempty"`
	OrderID    string      `json:"order_id,omitempty"`
	Symbol     string      `json:"symbol,omitempty"`
	Side       string      `json:"side,omitempty"`
	Action     string      `json:"action,omitempty"`
	Lots       float64     `json:"lots,omitempty"`
	Price      float64     `json:"price,omitempty"`
	SL         float64     `json:"sl,omitempty"`
	TP         float64     `json:"tp,omitempty"`
	Ticket     int64       `json:"ticket,omitempty"`
	Comment    string      `json:"comment,omitempty"`
	Status     string      `json:"status,omitempty"`
	FillPrice  float64     `json:"fill_price,omitempty"`
	Error      string      `json:"error,omitempty"`
	Bid        float64     `json:"bid,omitempty"`
	Ask        float64     `json:"ask,omitempty"`
	Balance    float64     `json:"balance,omitempty"`
	Equity     float64     `json:"equity,omitempty"`
	Margin     float64     `json:"margin,omitempty"`
	FreeMargin float64     `json:"free_margin,omitempty"`
	Profit     float64     `json:"profit,omitempty"`
	Leverage   int         `json:"leverage,omitempty"`
	Data       interface{} `json:"data,omitempty"`
	Symbols    []string    `json:"symbols,omitempty"`
	Timestamp  int64       `json:"ts,omitempty"`
}

// ==================== 终端会话 ====================

type Terminal struct {
	ID         string
	Platform   string // mt4, mt5
	Conn       *websocket.Conn
	Account    AccountInfo
	Positions  []Position
	LastPing   time.Time
	SendChan   chan []byte
	mu         sync.Mutex
}

type AccountInfo struct {
	Balance    float64 `json:"balance"`
	Equity     float64 `json:"equity"`
	Margin     float64 `json:"margin"`
	FreeMargin float64 `json:"free_margin"`
	Profit     float64 `json:"profit"`
	Leverage   int     `json:"leverage"`
}

type Position struct {
	Ticket       int64   `json:"ticket"`
	Symbol       string  `json:"symbol"`
	Side         string  `json:"side"`
	Lots         float64 `json:"lots"`
	OpenPrice    float64 `json:"open_price"`
	CurrentPrice float64 `json:"current_price"`
	SL           float64 `json:"sl"`
	TP           float64 `json:"tp"`
	Profit       float64 `json:"profit"`
	Swap         float64 `json:"swap"`
	Comment      string  `json:"comment"`
}

// ==================== 桥接服务器 ====================

type BridgeServer struct {
	terminals map[string]*Terminal
	mu        sync.RWMutex
	upgrader  websocket.Upgrader

	// 待处理的订单回调
	pendingOrders map[string]chan Message
	orderMu       sync.RWMutex
}

func NewBridgeServer() *BridgeServer {
	return &BridgeServer{
		terminals:     make(map[string]*Terminal),
		pendingOrders: make(map[string]chan Message),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
			ReadBufferSize:  4096,
			WriteBufferSize: 4096,
		},
	}
}

// ==================== WebSocket 处理 ====================

func (s *BridgeServer) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}

	terminalID := r.URL.Query().Get("terminal_id")
	if terminalID == "" {
		terminalID = uuid.New().String()[:8]
	}
	platform := r.URL.Query().Get("platform")
	if platform == "" {
		platform = "mt4"
	}

	terminal := &Terminal{
		ID:       terminalID,
		Platform: platform,
		Conn:     conn,
		LastPing: time.Now(),
		SendChan: make(chan []byte, 100),
	}

	s.mu.Lock()
	s.terminals[terminalID] = terminal
	s.mu.Unlock()

	log.Printf("✅ Terminal connected: %s (%s)", terminalID, platform)

	// 启动读写协程
	go s.readPump(terminal)
	go s.writePump(terminal)
}

func (s *BridgeServer) readPump(t *Terminal) {
	defer func() {
		s.removeTerminal(t)
		t.Conn.Close()
	}()

	t.Conn.SetReadLimit(8192)
	t.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	t.Conn.SetPongHandler(func(string) error {
		t.LastPing = time.Now()
		t.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := t.Conn.ReadMessage()
		if err != nil {
			log.Printf("Terminal %s read error: %v", t.ID, err)
			return
		}

		var msg Message
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("Terminal %s invalid message: %v", t.ID, err)
			continue
		}

		s.handleMessage(t, msg)
	}
}

func (s *BridgeServer) writePump(t *Terminal) {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		t.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-t.SendChan:
			if !ok {
				t.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			t.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := t.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			t.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := t.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ==================== 消息处理 ====================

func (s *BridgeServer) handleMessage(t *Terminal, msg Message) {
	switch msg.Type {
	case "ping":
		t.LastPing = time.Now()
		s.sendToTerminal(t, Message{Type: "pong", Timestamp: time.Now().Unix()})

	case "account":
		t.Account = AccountInfo{
			Balance:    msg.Balance,
			Equity:     msg.Equity,
			Margin:     msg.Margin,
			FreeMargin: msg.FreeMargin,
			Profit:     msg.Profit,
			Leverage:   msg.Leverage,
		}
		log.Printf("📊 Terminal %s account: Balance=%.2f, Equity=%.2f", t.ID, msg.Balance, msg.Equity)

	case "positions":
		if data, ok := msg.Data.([]interface{}); ok {
			positions := make([]Position, 0, len(data))
			for _, d := range data {
				b, _ := json.Marshal(d)
				var p Position
				json.Unmarshal(b, &p)
				positions = append(positions, p)
			}
			t.Positions = positions
		}

	case "tick":
		// 行情数据，转发给后端
		log.Printf("📈 Tick: %s %.5f/%.5f", msg.Symbol, msg.Bid, msg.Ask)

	case "order_result":
		// 订单执行结果
		s.handleOrderResult(msg)

	case "subscribe":
		log.Printf("📡 Terminal %s subscribed to: %v", t.ID, msg.Symbols)

	default:
		log.Printf("Unknown message type from %s: %s", t.ID, msg.Type)
	}
}

func (s *BridgeServer) handleOrderResult(msg Message) {
	s.orderMu.Lock()
	ch, exists := s.pendingOrders[msg.OrderID]
	if exists {
		ch <- msg
		delete(s.pendingOrders, msg.OrderID)
	}
	s.orderMu.Unlock()

	if exists {
		log.Printf("📬 Order %s result: %s, price=%.5f", msg.OrderID, msg.Status, msg.FillPrice)
	}
}

// ==================== 终端管理 ====================

func (s *BridgeServer) removeTerminal(t *Terminal) {
	s.mu.Lock()
	delete(s.terminals, t.ID)
	s.mu.Unlock()
	log.Printf("❌ Terminal disconnected: %s", t.ID)
}

func (s *BridgeServer) getTerminal(id string) *Terminal {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.terminals[id]
}

func (s *BridgeServer) getAllTerminals() []*Terminal {
	s.mu.RLock()
	defer s.mu.RUnlock()
	terminals := make([]*Terminal, 0, len(s.terminals))
	for _, t := range s.terminals {
		terminals = append(terminals, t)
	}
	return terminals
}

func (s *BridgeServer) sendToTerminal(t *Terminal, msg Message) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	select {
	case t.SendChan <- data:
		return nil
	default:
		return fmt.Errorf("send buffer full for terminal %s", t.ID)
	}
}

// ==================== 订单 API ====================

// SendOrder 向终端发送订单
func (s *BridgeServer) SendOrder(terminalID string, order Message) (Message, error) {
	t := s.getTerminal(terminalID)
	if t == nil {
		return Message{}, fmt.Errorf("terminal %s not found", terminalID)
	}

	// 生成订单 ID
	if order.OrderID == "" {
		order.OrderID = uuid.New().String()
	}
	order.Type = "order"

	// 创建回调通道
	resultCh := make(chan Message, 1)
	s.orderMu.Lock()
	s.pendingOrders[order.OrderID] = resultCh
	s.orderMu.Unlock()

	// 发送订单
	if err := s.sendToTerminal(t, order); err != nil {
		s.orderMu.Lock()
		delete(s.pendingOrders, order.OrderID)
		s.orderMu.Unlock()
		return Message{}, err
	}

	// 等待结果 (超时 10 秒)
	select {
	case result := <-resultCh:
		return result, nil
	case <-time.After(10 * time.Second):
		s.orderMu.Lock()
		delete(s.pendingOrders, order.OrderID)
		s.orderMu.Unlock()
		return Message{Status: "timeout"}, fmt.Errorf("order timeout")
	}
}

// ==================== HTTP API ====================

func (s *BridgeServer) HandleAPI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.URL.Path {
	case "/api/terminals":
		s.apiTerminals(w, r)
	case "/api/order":
		s.apiOrder(w, r)
	case "/api/account":
		s.apiAccount(w, r)
	case "/api/positions":
		s.apiPositions(w, r)
	default:
		http.Error(w, "not found", 404)
	}
}

func (s *BridgeServer) apiTerminals(w http.ResponseWriter, r *http.Request) {
	terminals := s.getAllTerminals()
	type TerminalInfo struct {
		ID       string      `json:"id"`
		Platform string      `json:"platform"`
		Account  AccountInfo `json:"account"`
		Positions int        `json:"positions"`
		LastPing  time.Time  `json:"last_ping"`
	}

	infos := make([]TerminalInfo, len(terminals))
	for i, t := range terminals {
		infos[i] = TerminalInfo{
			ID:        t.ID,
			Platform:  t.Platform,
			Account:   t.Account,
			Positions: len(t.Positions),
			LastPing:  t.LastPing,
		}
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"terminals": infos,
		"count":     len(infos),
	})
}

func (s *BridgeServer) apiOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST only", 405)
		return
	}

	var req struct {
		TerminalID string  `json:"terminal_id"`
		Action     string  `json:"action"` // open, close, modify
		Symbol     string  `json:"symbol"`
		Side       string  `json:"side"` // buy, sell
		Lots       float64 `json:"lots"`
		Price      float64 `json:"price"`
		SL         float64 `json:"sl"`
		TP         float64 `json:"tp"`
		Ticket     int64   `json:"ticket"`
		Comment    string  `json:"comment"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	result, err := s.SendOrder(req.TerminalID, Message{
		Action:  req.Action,
		Symbol:  req.Symbol,
		Side:    req.Side,
		Lots:    req.Lots,
		Price:   req.Price,
		SL:      req.SL,
		TP:      req.TP,
		Ticket:  req.Ticket,
		Comment: req.Comment,
	})

	if err != nil {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":  err.Error(),
			"result": result,
		})
		return
	}

	json.NewEncoder(w).Encode(result)
}

func (s *BridgeServer) apiAccount(w http.ResponseWriter, r *http.Request) {
	terminalID := r.URL.Query().Get("terminal_id")
	t := s.getTerminal(terminalID)
	if t == nil {
		json.NewEncoder(w).Encode(map[string]string{"error": "terminal not found"})
		return
	}
	json.NewEncoder(w).Encode(t.Account)
}

func (s *BridgeServer) apiPositions(w http.ResponseWriter, r *http.Request) {
	terminalID := r.URL.Query().Get("terminal_id")
	t := s.getTerminal(terminalID)
	if t == nil {
		json.NewEncoder(w).Encode(map[string]string{"error": "terminal not found"})
		return
	}
	json.NewEncoder(w).Encode(map[string]interface{}{
		"positions": t.Positions,
		"count":     len(t.Positions),
	})
}

// ==================== 主入口 ====================

func main() {
	port := os.Getenv("BRIDGE_PORT")
	if port == "" {
		port = "9090"
	}

	server := NewBridgeServer()

	// WebSocket 端点
	http.HandleFunc("/ws", server.HandleWebSocket)

	// HTTP API 端点
	http.HandleFunc("/api/", server.HandleAPI)

	// 健康检查
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":    "ok",
			"service":   "mt-bridge",
			"terminals": len(server.terminals),
		})
	})

	log.Printf("🌉 MT Bridge Server starting on :%s", port)
	log.Printf("   WebSocket: ws://localhost:%s/ws?terminal_id=xxx&platform=mt4", port)
	log.Printf("   API:       http://localhost:%s/api/", port)

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
