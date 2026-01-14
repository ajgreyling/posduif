package models

import (
	"time"
)

type SyncMetadata struct {
	ID                   string     `json:"id" db:"id"`
	DeviceID             string     `json:"device_id" db:"device_id"`
	LastSyncTimestamp    *time.Time `json:"last_sync_timestamp,omitempty" db:"last_sync_timestamp"`
	LastSyncedLSN        *string    `json:"last_synced_lsn,omitempty" db:"last_synced_lsn"`
	PendingOutgoingCount int        `json:"pending_outgoing_count" db:"pending_outgoing_count"`
	SyncStatus           string     `json:"sync_status" db:"sync_status"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
}

type SyncStatus struct {
	DeviceID             string     `json:"device_id"`
	LastSyncTimestamp    *time.Time `json:"last_sync_timestamp,omitempty"`
	PendingOutgoingCount int        `json:"pending_outgoing_count"`
	SyncStatus           string     `json:"sync_status"`
}

type SyncIncomingResponse struct {
	Messages      []Message `json:"messages"`
	Users         []User    `json:"users,omitempty"`
	Compressed    bool      `json:"compressed"`
	SyncTimestamp time.Time `json:"sync_timestamp"`
}

type SyncOutgoingRequest struct {
	Messages   []Message `json:"messages"`
	Compressed bool      `json:"compressed"`
}

type SyncOutgoingResponse struct {
	SyncedCount    int             `json:"synced_count"`
	FailedCount    int             `json:"failed_count"`
	FailedMessages []FailedMessage `json:"failed_messages,omitempty"`
	SyncTimestamp  time.Time       `json:"sync_timestamp"`
}

type FailedMessage struct {
	MessageID string `json:"message_id"`
	Error     string `json:"error"`
}


