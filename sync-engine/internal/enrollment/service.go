package enrollment

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"posduif/sync-engine/internal/config"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
)

type Service struct {
	db     *database.DB
	config *config.Config
}

func NewService(db *database.DB, cfg *config.Config) *Service {
	return &Service{
		db:     db,
		config: cfg,
	}
}

func (s *Service) CreateEnrollment(ctx context.Context, createdByUserID string) (*models.EnrollmentResponse, error) {
	token := &models.EnrollmentToken{
		CreatedBy: createdByUserID,
		TenantID:  s.config.Postgres.DB, // Use database name as tenant ID
		ExpiresAt: time.Now().Add(1 * time.Hour),
	}

	if err := s.db.CreateEnrollmentToken(ctx, token); err != nil {
		return nil, fmt.Errorf("failed to create enrollment token: %w", err)
	}

	enrollmentURL := fmt.Sprintf("http://localhost:%d/api/enrollment/%s", 
		s.config.SSE.Port, token.Token)

	qrCodeData := map[string]interface{}{
		"enrollment_url": enrollmentURL,
		"token":          token.Token,
		"tenant_id":      token.TenantID,
	}

	response := &models.EnrollmentResponse{
		Token:      token.Token,
		QRCodeData: qrCodeData,
		ExpiresAt:  token.ExpiresAt,
	}

	return response, nil
}

func (s *Service) GetEnrollment(ctx context.Context, token string) (*models.EnrollmentDetails, error) {
	et, err := s.db.GetEnrollmentToken(ctx, token)
	if err != nil {
		return nil, fmt.Errorf("enrollment token not found: %w", err)
	}

	valid := time.Now().Before(et.ExpiresAt) && et.UsedAt == nil

	details := &models.EnrollmentDetails{
		Token:     et.Token,
		TenantID:  et.TenantID,
		CreatedBy: et.CreatedBy,
		ExpiresAt: et.ExpiresAt,
		UsedAt:    et.UsedAt,
		Valid:     valid,
	}

	return details, nil
}

func (s *Service) CompleteEnrollment(ctx context.Context, req *models.CompleteEnrollmentRequest) (*models.EnrollmentResult, error) {
	// Get token details
	et, err := s.db.GetEnrollmentToken(ctx, req.Token)
	if err != nil {
		return nil, fmt.Errorf("enrollment token not found: %w", err)
	}

	// Complete enrollment (creates user and marks token as used)
	if err := s.db.CompleteEnrollment(ctx, req.Token, req.DeviceID); err != nil {
		return nil, fmt.Errorf("failed to complete enrollment: %w", err)
	}

	// Get created user
	users, err := s.db.GetUsers(ctx, models.UserFilter{})
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	var userID string
	for _, user := range users {
		if user.DeviceID != nil && *user.DeviceID == req.DeviceID {
			userID = user.ID
			break
		}
	}

	if userID == "" {
		return nil, fmt.Errorf("failed to find created user")
	}

	appInstructionsURL := fmt.Sprintf("http://localhost:%d/api/app-instructions", s.config.SSE.Port)

	result := &models.EnrollmentResult{
		UserID:             userID,
		DeviceID:           req.DeviceID,
		TenantID:           et.TenantID,
		AppInstructionsURL: appInstructionsURL,
	}

	return result, nil
}

func (s *Service) GetAppInstructions(ctx context.Context, deviceID string) (*models.AppInstructions, error) {
	// Get user by device ID
	users, err := s.db.GetUsers(ctx, models.UserFilter{})
	if err != nil {
		return nil, fmt.Errorf("failed to get users: %w", err)
	}

	var tenantID string
	for _, user := range users {
		if user.DeviceID != nil && *user.DeviceID == deviceID {
			tenantID = s.config.Postgres.DB
			break
		}
	}

	if tenantID == "" {
		return nil, fmt.Errorf("device not enrolled")
	}

	apiBaseURL := fmt.Sprintf("http://localhost:%d", s.config.SSE.Port)

	instructions := &models.AppInstructions{
		Version:    "1.0.0",
		TenantID:   tenantID,
		APIBaseURL: apiBaseURL,
		Widgets: map[string]models.WidgetConfig{
			"inbox": {
				Type:    "remote_widget",
				URL:     fmt.Sprintf("%s/widgets/inbox.json", apiBaseURL),
				Version: "1.0.0",
			},
			"compose": {
				Type:    "remote_widget",
				URL:     fmt.Sprintf("%s/widgets/compose.json", apiBaseURL),
				Version: "1.0.0",
			},
			"message_detail": {
				Type:    "remote_widget",
				URL:     fmt.Sprintf("%s/widgets/message_detail.json", apiBaseURL),
				Version: "1.0.0",
			},
		},
		SyncConfig: models.SyncConfig{
			BatchSize:            s.config.Sync.BatchSize,
			Compression:          s.config.Sync.Compression,
			SyncIntervalSeconds:  300,
		},
	}

	return instructions, nil
}

