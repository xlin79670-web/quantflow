package config

import "os"

type Config struct {
	Port            string
	DatabaseURL     string
	RedisURL        string
	JWTSecret       string
	BinanceAPIKey   string
	BinanceSecretKey string
	BinanceBaseURL  string
	AIServiceURL    string
}

func Load() *Config {
	return &Config{
		Port:             getEnv("PORT", "8080"),
		DatabaseURL:      getEnv("DATABASE_URL", "postgres://quantflow:quantflow@localhost:5432/quantflow?sslmode=disable"),
		RedisURL:         getEnv("REDIS_URL", "localhost:6379"),
		JWTSecret:        getEnv("JWT_SECRET", "change-me-in-production"),
		BinanceAPIKey:    os.Getenv("BINANCE_API_KEY"),
		BinanceSecretKey: os.Getenv("BINANCE_SECRET_KEY"),
		BinanceBaseURL:   getEnv("BINANCE_BASE_URL", "https://api.binance.com"),
		AIServiceURL:     getEnv("AI_SERVICE_URL", "http://localhost:8000"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
