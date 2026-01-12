package sync

import (
	"context"
	"fmt"
	"time"

	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
)

type Manager struct {
	db *database.DB
}

func NewManager(db *database.DB) *Manager {
	return &Manager{db: db}
}

func (m *Manager) PerformSync(ctx context.Context, deviceID string) error {
	// Update sync status to syncing
	sm, err := m.db.GetSyncMetadata(ctx, deviceID)
	if err != nil {
		sm = &models.SyncMetadata{
			DeviceID:   deviceID,
			SyncStatus: "syncing",
		}
	} else {
		sm.SyncStatus = "syncing"
	}
	m.db.UpdateSyncMetadata(ctx, sm)

	// Sync incoming messages
	incoming, err := m.db.GetPendingMessagesForDevice(ctx, deviceID, 100)
	if err != nil {
		sm.SyncStatus = "error"
		m.db.UpdateSyncMetadata(ctx, sm)
		return fmt.Errorf("failed to get incoming messages: %w", err)
	}

	// Update message status to synced
	for _, msg := range incoming {
		m.db.UpdateMessageStatus(ctx, msg.ID, "synced")
	}

	// Update sync metadata
	now := time.Now()
	sm.LastSyncTimestamp = &now
	sm.SyncStatus = "idle"
	sm.PendingOutgoingCount = 0 // Would be calculated from local DB
	m.db.UpdateSyncMetadata(ctx, sm)

	return nil
}

func (m *Manager) SyncIncoming(ctx context.Context, deviceID string, limit int) ([]models.Message, error) {
	messages, err := m.db.GetPendingMessagesForDevice(ctx, deviceID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending messages: %w", err)
	}

	// Update status to synced
	for _, msg := range messages {
		if err := m.db.UpdateMessageStatus(ctx, msg.ID, "synced"); err != nil {
			return nil, fmt.Errorf("failed to update message status: %w", err)
		}
	}

	return messages, nil
}

func (m *Manager) SyncOutgoing(ctx context.Context, messages []models.Message) (int, int, []models.FailedMessage) {
	syncedCount := 0
	failedCount := 0
	var failedMessages []models.FailedMessage

	for _, msg := range messages {
		if err := m.db.CreateMessage(ctx, &msg); err != nil {
			failedCount++
			failedMessages = append(failedMessages, models.FailedMessage{
				MessageID: msg.ID,
				Error:     err.Error(),
			})
		} else {
			syncedCount++
		}
	}

	return syncedCount, failedCount, failedMessages
}


