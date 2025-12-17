package models

import (
	"time"
)

type EnrollmentToken struct {
	ID        string     `json:"id" db:"id"`
	Token     string     `json:"token" db:"token"`
	CreatedBy string     `json:"created_by" db:"created_by"`
	TenantID  string     `json:"tenant_id" db:"tenant_id"`
	ExpiresAt time.Time  `json:"expires_at" db:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty" db:"used_at"`
	DeviceID  *string    `json:"device_id,omitempty" db:"device_id"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
}

type EnrollmentResponse struct {
	Token      string                 `json:"token"`
	QRCodeData map[string]interface{} `json:"qr_code_data"`
	ExpiresAt  time.Time              `json:"expires_at"`
}

type EnrollmentDetails struct {
	Token     string     `json:"token"`
	TenantID  string     `json:"tenant_id"`
	CreatedBy string     `json:"created_by"`
	ExpiresAt time.Time  `json:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
	Valid     bool       `json:"valid"`
}

type CompleteEnrollmentRequest struct {
	Token      string                 `json:"token"`
	DeviceID   string                 `json:"device_id"`
	DeviceInfo map[string]interface{} `json:"device_info"`
}

type EnrollmentResult struct {
	UserID             string `json:"user_id"`
	DeviceID           string `json:"device_id"`
	TenantID           string `json:"tenant_id"`
	AppInstructionsURL string `json:"app_instructions_url"`
}

type AppInstructions struct {
	Version    string                  `json:"version"`
	TenantID   string                  `json:"tenant_id"`
	APIBaseURL string                  `json:"api_base_url"`
	Widgets    map[string]WidgetConfig `json:"widgets"`
	SyncConfig SyncConfig              `json:"sync_config"`
}

type WidgetConfig struct {
	Type    string `json:"type"`
	URL     string `json:"url"`
	Version string `json:"version"`
}

type SyncConfig struct {
	BatchSize           int  `json:"batch_size"`
	Compression         bool `json:"compression"`
	SyncIntervalSeconds int  `json:"sync_interval_seconds"`
}
