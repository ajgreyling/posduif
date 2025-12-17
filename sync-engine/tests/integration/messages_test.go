package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"posduif/sync-engine/internal/api/handlers"
	"posduif/sync-engine/internal/api/middleware"
	"posduif/sync-engine/internal/config"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
	"posduif/sync-engine/internal/redis"
)

func TestCreateMessage(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()

	// Create test users
	webUser := &models.User{
		Username: "test_web_user",
		UserType: "web",
	}
	db.CreateUser(context.Background(), webUser)

	mobileUser := &models.User{
		Username: "test_mobile_user",
		UserType: "mobile",
	}
	db.CreateUser(context.Background(), mobileUser)

	// Create handler
	redisClient, _ := redis.NewClient(&config.Config{
		Redis: config.RedisConfig{
			Host: "localhost",
			Port: 6379,
		},
	})
	defer redisClient.Close()

	publisher := redis.NewPublisher(redisClient.GetClient(), &config.Config{})
	handler := handlers.NewMessagesHandler(db, publisher)

	// Create authenticated request
	req := httptest.NewRequest("POST", "/api/messages", bytes.NewBuffer([]byte(`{
		"recipient_id": "`+mobileUser.ID+`",
		"content": "Test message"
	}`)))
	req.Header.Set("Content-Type", "application/json")
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, webUser.ID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.CreateMessage(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("Expected status 201, got %d", w.Code)
	}

	var msg models.Message
	if err := json.NewDecoder(w.Body).Decode(&msg); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if msg.Content != "Test message" {
		t.Errorf("Expected content 'Test message', got '%s'", msg.Content)
	}

	if msg.Status != "pending_sync" {
		t.Errorf("Expected status 'pending_sync', got '%s'", msg.Status)
	}
}
