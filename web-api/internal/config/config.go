package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Port     int          `yaml:"port"`
	Postgres PostgresConfig `yaml:"postgres"`
}

type PostgresConfig struct {
	Host     string `yaml:"host"`
	Port     int    `yaml:"port"`
	User     string `yaml:"user"`
	Password string `yaml:"password"`
	DB       string `yaml:"db"`
}

func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	// Set defaults
	if cfg.Port == 0 {
		cfg.Port = 8081 // Different port from sync engine
	}

	// Override with environment variables if set (for Docker/containerized deployments)
	if portEnv := os.Getenv("PORT"); portEnv != "" {
		var port int
		if _, err := fmt.Sscanf(portEnv, "%d", &port); err == nil {
			cfg.Port = port
		}
	}
	if host := os.Getenv("POSTGRES_HOST"); host != "" {
		cfg.Postgres.Host = host
	}
	if portEnv := os.Getenv("POSTGRES_PORT"); portEnv != "" {
		var port int
		if _, err := fmt.Sscanf(portEnv, "%d", &port); err == nil {
			cfg.Postgres.Port = port
		}
	}
	if user := os.Getenv("POSTGRES_USER"); user != "" {
		cfg.Postgres.User = user
	}
	if password := os.Getenv("POSTGRES_PASSWORD"); password != "" {
		cfg.Postgres.Password = password
	}
	if db := os.Getenv("POSTGRES_DB"); db != "" {
		cfg.Postgres.DB = db
	}

	return &cfg, nil
}
