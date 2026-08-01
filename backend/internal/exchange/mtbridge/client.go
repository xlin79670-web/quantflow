package mtbridge

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// ==================== 消息定义 ====================

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
	Profit     float64     `json:"profit,omitempty"`
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

// ==================== MT Bridge 客户端 ====================

type Client struct {
	bridgeURL  string
	conn       *websocket.Conn
	terminals  map[string]*TerminalState
	mu         sync.RWMutex
	onTick     func(terminalID string, symbol string, bid, ask float64)
	onAccount  func(terminalID string, account AccountInfo)
}

type TerminalState struct {
	ID       string
	Platform string
	Account  AccountInfo
	LastPing time.Time
}

func NewClient(bridgeURL string) *Client {
	return &Client{
		bridgeURL: bridgeURL,
		terminals: make(map[string]*TerminalState),
	}
}

// Connect 连接到 MT Bridge 服务器
func (c *Client) Connect() error {
	conn, _, err := websocket.DefaultDialer.Dial(c.bridgeURL, nil)
	if err != nil {
		return fmt.Errorf("bridge connect failed: %w", err)
	}
	c.conn = conn

	go c.readPump()
	log.Printf("✅ Connected to MT Bridge: %s", c.bridgeURL)
	return nil
}

func (c *Client) readPump() {
	defer c.conn.Close()

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			log.Printf("Bridge read error: %v", err)
			return
		}

		var msg Message
		if err := json.Unmarshal(message, &msg); err != nil {
			continue
		}

		c.handleMessage(msg)
	}
}

func (c *Client) handleMessage(msg Message) {
	switch msg.Type {
	case "tick":
		if c.onTick != nil {
			c.onTick(msg.TerminalID, msg.Symbol, msg.Bid, msg.Ask)
		}

	case "account":
		c.mu.Lock()
		if t, ok := c.terminals[msg.TerminalID]; ok {
			t.Account = AccountInfo{
				Balance: msg.Balance, Equity: msg.Equity,
				Profit: msg.Profit,
			}
		}
		c.mu.Unlock()

		if c.onAccount != nil {
			c.onAccount(msg.TerminalID, AccountInfo{
				Balance: msg.Balance, Equity: msg.Equity, Profit: msg.Profit,
			})
		}

	case "pong":
		c.mu.Lock()
		if t, ok := c.terminals[msg.TerminalID]; ok {
			t.LastPing = time.Now()
		}
		c.mu.Unlock()
	}
}

// ==================== 交易操作 ====================

// OpenPosition 开仓
func (c *Client) OpenPosition(terminalID, symbol, side string, lots, sl, tp float64, comment string) (Message, error) {
	return c.sendOrder(terminalID, Message{
		Action:  "open",
		Symbol:  symbol,
		Side:    side,
		Lots:    lots,
		SL:      sl,
		TP:      tp,
		Comment: comment,
	})
}

// ClosePosition 平仓
func (c *Client) ClosePosition(terminalID string, ticket int64) (Message, error) {
	return c.sendOrder(terminalID, Message{
		Action: "close",
		Ticket: ticket,
	})
}

// ModifyPosition 修改止损止盈
func (c *Client) ModifyPosition(terminalID string, ticket int64, sl, tp float64) (Message, error) {
	return c.sendOrder(terminalID, Message{
		Action: "modify",
		Ticket: ticket,
		SL:     sl,
		TP:     tp,
	})
}

func (c *Client) sendOrder(terminalID string, order Message) (Message, error) {
	order.Type = "order"
	order.TerminalID = terminalID

	data, err := json.Marshal(order)
	if err != nil {
		return Message{}, err
	}

	if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
		return Message{}, err
	}

	// 等待结果 (简化版本，生产环境应使用回调)
	time.Sleep(100 * time.Millisecond)
	return Message{Status: "sent"}, nil
}

// ==================== 回调设置 ====================

func (c *Client) OnTick(handler func(terminalID, symbol string, bid, ask float64)) {
	c.onTick = handler
}

func (c *Client) OnAccount(handler func(terminalID string, account AccountInfo)) {
	c.onAccount = handler
}

// GetTerminals 获取已连接的终端列表
func (c *Client) GetTerminals() []TerminalState {
	c.mu.RLock()
	defer c.mu.RUnlock()

	terminals := make([]TerminalState, 0, len(c.terminals))
	for _, t := range c.terminals {
		terminals = append(terminals, *t)
	}
	return terminals
}
