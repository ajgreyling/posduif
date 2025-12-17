package integration

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"posduif/sync-engine/internal/api/handlers"
	"posduif/sync-engine/internal/config"
	"posduif/sync-engine/internal/database"
)

func setupTestDB(t *testing.T) *database.DB {
	cfg := &config.Config{
		Postgres: config.PostgresConfig{
			Host:     "localhost",
			Port:     5432,
			User:     "posduif",
			Password: "secret",
			DB:       "tenant_1",
		},
	}

	db, err := database.NewDB(cfg)
	if err != nil {
		t.Fatalf("Failed to connect to test database: %v", err)
	}
	return db
}

func TestLogin(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()

	handler := handlers.NewAuthHandler(db, "test-secret", 3600)

	loginReq := map[string]string{
		"username": "web_user_1",
		"password": "password",
	}

	body, _ := json.Marshal(loginReq)
	req := httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	handler.Login(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["token"] == nil {
		t.Error("Expected token in response")
	}
}

func TestLoginInvalidCredentials(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()

	handler := handlers.NewAuthHandler(db, "test-secret", 3600)

	loginReq := map[string]string{
		"username": "nonexistent_user",
		"password": "password",
	}

	body, _ := json.Marshal(loginReq)
	req := httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	handler.Login(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}
