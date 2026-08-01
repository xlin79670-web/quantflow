package binance

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"quantflow/internal/model"

	"github.com/gorilla/websocket"
	"go.uber.org/zap"
)

const (
	baseREST = "https://api.binance.com"
	baseWS   = "wss://stream.binance.com:9443/ws"
)

// Client 币安 API 客户端
type Client struct {
	apiKey    string
	secretKey string
	baseURL   string
	http      *http.Client
	logger    *zap.SugaredLogger
}

func NewClient(apiKey, secretKey, baseURL string) *Client {
	if baseURL == "" {
		baseURL = baseREST
	}
	return &Client{
		apiKey:    apiKey,
		secretKey: secretKey,
		baseURL:   baseURL,
		http:      &http.Client{Timeout: 10 * time.Second},
	}
}

// ==================== 公开 API ====================

// GetTicker 获取最新价格
func (c *Client) GetTicker(symbol string) (*model.Ticker, error) {
	path := fmt.Sprintf("/api/v3/ticker/24hr?symbol=%s", symbol)
	body, err := c.publicRequest(path)
	if err != nil {
		return nil, err
	}

	var raw struct {
		Symbol    string `json:"symbol"`
		LastPrice string `json:"lastPrice"`
		PriceChangePercent string `json:"priceChangePercent"`
		Volume    string `json:"volume"`
		HighPrice string `json:"highPrice"`
		LowPrice  string `json:"lowPrice"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, err
	}

	return &model.Ticker{
		Symbol:    raw.Symbol,
		Price:     parseFloat(raw.LastPrice),
		Change24h: parseFloat(raw.PriceChangePercent),
		Volume24h: parseFloat(raw.Volume),
		High24h:   parseFloat(raw.HighPrice),
		Low24h:    parseFloat(raw.LowPrice),
	}, nil
}

// GetKlines 获取 K 线数据
func (c *Client) GetKlines(symbol, interval string, limit int) ([]model.Kline, error) {
	path := fmt.Sprintf("/api/v3/klines?symbol=%s&interval=%s&limit=%d", symbol, interval, limit)
	body, err := c.publicRequest(path)
	if err != nil {
		return nil, err
	}

	var raw [][]interface{}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, err
	}

	klines := make([]model.Kline, 0, len(raw))
	for _, k := range raw {
		if len(k) < 6 {
			continue
		}
		klines = append(klines, model.Kline{
			Symbol:    symbol,
			Timeframe: interval,
			OpenTime:  time.UnixMilli(int64(k[0].(float64))),
			Open:      parseFloat(k[1].(string)),
			High:      parseFloat(k[2].(string)),
			Low:       parseFloat(k[3].(string)),
			Close:     parseFloat(k[4].(string)),
			Volume:    parseFloat(k[5].(string)),
			Closed:    true,
		})
	}
	return klines, nil
}

// ==================== 签名 API ====================

// GetAccount 获取账户信息
func (c *Client) GetAccount() (map[string]interface{}, error) {
	params := url.Values{}
	params.Set("timestamp", strconv.FormatInt(time.Now().UnixMilli(), 10))
	params.Set("signature", c.sign(params.Encode()))

	path := "/api/v3/account?" + params.Encode()
	body, err := c.signedRequest(path)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}
	return result, nil
}

// GetBalances 获取余额
func (c *Client) GetBalances() ([]map[string]string, error) {
	account, err := c.GetAccount()
	if err != nil {
		return nil, err
	}

	rawBalances, ok := account["balances"].([]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid balances format")
	}

	var balances []map[string]string
	for _, b := range rawBalances {
		bal := b.(map[string]interface{})
		free := bal["free"].(string)
		locked := bal["locked"].(string)
		if free != "0" || locked != "0" {
			balances = append(balances, map[string]string{
				"asset":  bal["asset"].(string),
				"free":   free,
				"locked": locked,
			})
		}
	}
	return balances, nil
}

// PlaceOrder 下单
func (c *Client) PlaceOrder(symbol, side, orderType string, quantity, price float64) (map[string]interface{}, error) {
	params := url.Values{}
	params.Set("symbol", symbol)
	params.Set("side", strings.ToUpper(side))
	params.Set("type", strings.ToUpper(orderType))
	params.Set("quantity", strconv.FormatFloat(quantity, 'f', -1, 64))

	if orderType == "LIMIT" {
		params.Set("timeInForce", "GTC")
		params.Set("price", strconv.FormatFloat(price, 'f', -1, 64))
	}

	params.Set("timestamp", strconv.FormatInt(time.Now().UnixMilli(), 10))
	params.Set("signature", c.sign(params.Encode()))

	path := "/api/v3/order"
	body, err := c.signedRequestPost(path, params)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}
	return result, nil
}

// CancelOrder 撤单
func (c *Client) CancelOrder(symbol string, orderID int64) (map[string]interface{}, error) {
	params := url.Values{}
	params.Set("symbol", symbol)
	params.Set("orderId", strconv.FormatInt(orderID, 10))
	params.Set("timestamp", strconv.FormatInt(time.Now().UnixMilli(), 10))
	params.Set("signature", c.sign(params.Encode()))

	path := "/api/v3/order?" + params.Encode()
	body, err := c.signedRequestDelete(path)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}
	return result, nil
}

// ==================== WebSocket ====================

// SubscribeKline 订阅 K 线推送
func (c *Client) SubscribeKline(symbol, interval string, handler func(model.Kline)) error {
	streamName := fmt.Sprintf("%s@kline_%s", strings.ToLower(symbol), interval)
	return c.connectWS(streamName, func(data []byte) {
		var raw struct {
			K struct {
				OpenTime int64  `json:"t"`
				Open     string `json:"o"`
				High     string `json:"h"`
				Low      string `json:"l"`
				Close    string `json:"c"`
				Volume   string `json:"v"`
				Closed   bool   `json:"x"`
			} `json:"k"`
		}
		if err := json.Unmarshal(data, &raw); err != nil {
			return
		}
		handler(model.Kline{
			Symbol:    symbol,
			Timeframe: interval,
			OpenTime:  time.UnixMilli(raw.K.OpenTime),
			Open:      parseFloat(raw.K.Open),
			High:      parseFloat(raw.K.High),
			Low:       parseFloat(raw.K.Low),
			Close:     parseFloat(raw.K.Close),
			Volume:    parseFloat(raw.K.Volume),
			Closed:    raw.K.Closed,
		})
	})
}

// SubscribeTicker 订阅价格推送
func (c *Client) SubscribeTicker(symbol string, handler func(model.Ticker)) error {
	streamName := fmt.Sprintf("%s@miniTicker", strings.ToLower(symbol))
	return c.connectWS(streamName, func(data []byte) {
		var raw struct {
			Symbol string `json:"s"`
			Close  string `json:"c"`
			High   string `json:"h"`
			Low    string `json:"l"`
			Volume string `json:"v"`
		}
		if err := json.Unmarshal(data, &raw); err != nil {
			return
		}
		handler(model.Ticker{
			Symbol:    raw.Symbol,
			Price:     parseFloat(raw.Close),
			High24h:   parseFloat(raw.High),
			Low24h:    parseFloat(raw.Low),
			Volume24h: parseFloat(raw.Volume),
		})
	})
}

// ==================== 内部方法 ====================

func (c *Client) publicRequest(path string) ([]byte, error) {
	resp, err := c.http.Get(c.baseURL + path)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}
	return body, nil
}

func (c *Client) signedRequest(path string) ([]byte, error) {
	req, _ := http.NewRequest("GET", c.baseURL+path, nil)
	req.Header.Set("X-MBX-APIKEY", c.apiKey)

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}
	return body, nil
}

func (c *Client) signedRequestPost(path string, params url.Values) ([]byte, error) {
	req, _ := http.NewRequest("POST", c.baseURL+"?"+params.Encode(), nil)
	req.Header.Set("X-MBX-APIKEY", c.apiKey)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}
	return body, nil
}

func (c *Client) signedRequestDelete(path string) ([]byte, error) {
	req, _ := http.NewRequest("DELETE", c.baseURL+path, nil)
	req.Header.Set("X-MBX-APIKEY", c.apiKey)

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}
	return body, nil
}

func (c *Client) connectWS(stream string, handler func([]byte)) error {
	wsURL := fmt.Sprintf("%s/%s", baseWS, stream)
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		return fmt.Errorf("WS connect failed: %w", err)
	}

	go func() {
		defer conn.Close()
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				c.logger.Errorf("WS read error: %v", err)
				return
			}
			handler(message)
		}
	}()
	return nil
}

func (c *Client) sign(query string) string {
	mac := hmac.New(sha256.New, []byte(c.secretKey))
	mac.Write([]byte(query))
	return hex.EncodeToString(mac.Sum(nil))
}

func parseFloat(s string) float64 {
	f, _ := strconv.ParseFloat(s, 64)
	return f
}
