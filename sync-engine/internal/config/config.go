package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Postgres PostgresConfig `yaml:"postgres"`
	Redis    RedisConfig    `yaml:"redis"`
	SSE      SSEConfig      `yaml:"sse"`
	Sync     SyncConfig     `yaml:"sync"`
	Auth     AuthConfig     `yaml:"auth"`
	Logging  LoggingConfig  `yaml:"logging"`
	CORS     CORSConfig     `yaml:"cors"`
}

type CORSConfig struct {
	Enabled        bool     `yaml:"enabled"`
	AllowedOrigins []string `yaml:"allowed_origins"`
	AllowedMethods []string `yaml:"allowed_methods"`
	AllowedHeaders []string `yaml:"allowed_headers"`
	MaxAge         int      `yaml:"max_age"`
}

type PostgresConfig struct {
	Host           string `yaml:"host"`
	Port           int    `yaml:"port"`
	User           string `yaml:"user"`
	Password       string `yaml:"password"`
	DB             string `yaml:"db"`
	MaxConnections int    `yaml:"max_connections"`
	SSLMode        string `yaml:"ssl_mode"`
	ConnectTimeout string `yaml:"connect_timeout"`
}

type RedisConfig struct {
	Host     string        `yaml:"host"`
	Port     int           `yaml:"port"`
	Password string        `yaml:"password"`
	DB       int           `yaml:"db"`
	Streams  StreamsConfig `yaml:"streams"`
}

type StreamsConfig struct {
	Enabled   bool `yaml:"enabled"`
	MaxLength int  `yaml:"max_length"`
}

type SSEConfig struct {
	Port         int    `yaml:"port"`
	ReadTimeout  string `yaml:"read_timeout"`
	WriteTimeout string `yaml:"write_timeout"`
	PingInterval string `yaml:"ping_interval"`
}

type SyncConfig struct {
	BatchSize            int        `yaml:"batch_size"`
	Compression          bool       `yaml:"compression"`
	CompressionThreshold int        `yaml:"compression_threshold"`
	ConflictResolution   string     `yaml:"conflict_resolution"`
	RetryAttempts        int        `yaml:"retry_attempts"`
	RetryBackoff         string     `yaml:"retry_backoff"`
	WAL                  WALConfig  `yaml:"wal"`
}

type WALConfig struct {
	Enabled      bool   `yaml:"enabled"`
	SlotName     string `yaml:"slot_name"`     // If empty, auto-generated from tenant DB name
	BatchSize    int    `yaml:"batch_size"`    // Number of changes to read per batch
	ReadInterval string `yaml:"read_interval"` // How often to read WAL changes
}

type AuthConfig struct {
	JWTSecret         string `yaml:"jwt_secret"`
	JWTExpiration     int    `yaml:"jwt_expiration"`
	PasswordMinLength int    `yaml:"password_min_length"`
	BcryptCost        int    `yaml:"bcrypt_cost"`
}

type LoggingConfig struct {
	Level    string `yaml:"level"`
	Format   string `yaml:"format"`
	Output   string `yaml:"output"`
	FilePath string `yaml:"file_path"`
}

func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	// Set defaults
	if config.Postgres.Port == 0 {
		config.Postgres.Port = 5432
	}
	if config.Redis.Port == 0 {
		config.Redis.Port = 6379
	}
	if config.SSE.Port == 0 {
		config.SSE.Port = 8080
	}
	if config.Postgres.MaxConnections == 0 {
		config.Postgres.MaxConnections = 25
	}
	if config.Sync.BatchSize == 0 {
		config.Sync.BatchSize = 100
	}
	if config.Sync.WAL.BatchSize == 0 {
		config.Sync.WAL.BatchSize = 100
	}
	if config.Sync.WAL.ReadInterval == "" {
		config.Sync.WAL.ReadInterval = "1s"
	}
	if config.Auth.JWTExpiration == 0 {
		config.Auth.JWTExpiration = 3600
	}

	// Set CORS defaults
	if len(config.CORS.AllowedMethods) == 0 {
		config.CORS.AllowedMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	}
	if len(config.CORS.AllowedHeaders) == 0 {
		config.CORS.AllowedHeaders = []string{"Content-Type", "Authorization", "X-Device-ID"}
	}

	return &config, nil
}
