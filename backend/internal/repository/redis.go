package repository

import (
	"context"
	"encoding/json"
	"time"

	"github.com/redis/go-redis/v9"
)

type Redis struct {
	client *redis.Client
}

func NewRedis(url string) *Redis {
	opt, _ := redis.ParseURL(url)
	if opt == nil {
		opt = &redis.Options{Addr: url}
	}
	return &Redis{client: redis.NewClient(opt)}
}

func (r *Redis) Close() {
	r.client.Close()
}

// 行情缓存
func (r *Redis) SetTicker(symbol string, data interface{}) error {
	b, _ := json.Marshal(data)
	return r.client.Set(context.Background(), "ticker:"+symbol, b, 5*time.Second).Err()
}

func (r *Redis) GetTicker(symbol string) (string, error) {
	return r.client.Get(context.Background(), "ticker:"+symbol).Result()
}

// 策略状态缓存
func (r *Redis) SetStrategyState(strategyID string, state interface{}) error {
	b, _ := json.Marshal(state)
	return r.client.Set(context.Background(), "strategy:state:"+strategyID, b, 0).Err()
}

func (r *Redis) GetStrategyState(strategyID string) (string, error) {
	return r.client.Get(context.Background(), "strategy:state:"+strategyID).Result()
}

// 发布/订阅 - 策略信号
func (r *Redis) PublishSignal(channel string, signal interface{}) error {
	b, _ := json.Marshal(signal)
	return r.client.Publish(context.Background(), channel, b).Err()
}

func (r *Redis) SubscribeSignals(channel string, handler func([]byte)) {
	sub := r.client.Subscribe(context.Background(), channel)
	ch := sub.Channel()
	go func() {
		for msg := range ch {
			handler([]byte(msg.Payload))
		}
	}()
}

// 限频 - API 调用计数
func (r *Redis) IncrAPICall(key string, window time.Duration) (int64, error) {
	ctx := context.Background()
	pipe := r.client.Pipeline()
	incr := pipe.Incr(ctx, "ratelimit:"+key)
	pipe.Expire(ctx, "ratelimit:"+key, window)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return 0, err
	}
	return incr.Val(), nil
}
