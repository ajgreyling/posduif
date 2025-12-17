package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"posduif/sync-engine/internal/api/handlers"
	"posduif/sync-engine/internal/api/middleware"
	"posduif/sync-engine/internal/config"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/enrollment"
	"posduif/sync-engine/internal/models"
)

func TestCreateEnrollment(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()

	// Create test web user
	webUser := &models.User{
		Username: "test_web_user",
		UserType: "web",
	}
	_ = db.CreateUser(context.Background(), webUser)

	// Create enrollment service and handler
	cfg := &config.Config{
		Postgres: config.PostgresConfig{DB: "tenant_1"},
		SSE:      config.SSEConfig{Port: 8080},
	}
	service := enrollment.NewService(db, cfg)
	handler := handlers.NewEnrollmentHandler(service)

	// Create authenticated request
	req := httptest.NewRequest("POST", "/api/enrollment/create", nil)
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, webUser.ID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.CreateEnrollment(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("Expected status 201, got %d", w.Code)
	}

	var response models.EnrollmentResponse
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.Token == "" {
		t.Error("Expected token in response")
	}

	if response.QRCodeData == nil {
		t.Error("Expected QR code data in response")
	}
}

func TestGetEnrollment(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()

	// Create test web user
	webUser := &models.User{
		Username: "test_web_user",
		UserType: "web",
	}
	_ = db.CreateUser(context.Background(), webUser)

	// Create enrollment token
	cfg := &config.Config{
		Postgres: config.PostgresConfig{DB: "tenant_1"},
		SSE:      config.SSEConfig{Port: 8080},
	}
	service := enrollment.NewService(db, cfg)
	enrollmentResp, _ := service.CreateEnrollment(context.Background(), webUser.ID)

	// Get enrollment
	handler := handlers.NewEnrollmentHandler(service)
	req := httptest.NewRequest("GET", "/api/enrollment/"+enrollmentResp.Token, nil)
	w := httptest.NewRecorder()
	handler.GetEnrollment(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var details models.EnrollmentDetails
	if err := json.NewDecoder(w.Body).Decode(&details); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if !details.Valid {
		t.Error("Expected enrollment token to be valid")
	}
}
