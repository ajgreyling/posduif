package sync

import (
	"context"
	"fmt"
	"time"

	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
)

type Manager struct {
	db            *database.DB
	changeTracker *ChangeTracker
	walEnabled    bool
}

func NewManager(db *database.DB, changeTracker *ChangeTracker, walEnabled bool) *Manager {
	return &Manager{
		db:            db,
		changeTracker: changeTracker,
		walEnabled:    walEnabled,
	}
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
	_, err = m.SyncIncoming(ctx, deviceID, 100)
	if err != nil {
		sm.SyncStatus = "error"
		m.db.UpdateSyncMetadata(ctx, sm)
		return fmt.Errorf("failed to get incoming messages: %w", err)
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
	if m.walEnabled {
		return m.syncIncomingWAL(ctx, deviceID, limit)
	}
	return m.syncIncomingPolling(ctx, deviceID, limit)
}

// syncIncomingWAL syncs incoming messages using WAL-based change detection
func (m *Manager) syncIncomingWAL(ctx context.Context, deviceID string, limit int) ([]models.Message, error) {
	// Get WAL changes for this device
	changes, err := m.changeTracker.GetChangesForDevice(ctx, deviceID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get WAL changes: %w", err)
	}

	// Convert WAL changes to messages
	messages := make([]models.Message, 0, len(changes))
	var maxLSN models.LSN

	for _, change := range changes {
		msg, err := ConvertWALChangeToMessage(change)
		if err != nil {
			// Skip invalid changes
			continue
		}

		messages = append(messages, *msg)
		if change.LSN > maxLSN {
			maxLSN = change.LSN
		}
	}

	// Update sync metadata with the latest LSN
	if len(messages) > 0 {
		sm, err := m.db.GetSyncMetadata(ctx, deviceID)
		if err != nil {
			sm = &models.SyncMetadata{
				DeviceID:   deviceID,
				SyncStatus: "syncing",
			}
		}

		// Update LSN - convert models.LSN to string
		lsnStr := maxLSN.String()
		sm.LastSyncedLSN = &lsnStr

		now := time.Now()
		sm.LastSyncTimestamp = &now
		sm.SyncStatus = "idle"

		if err := m.db.UpdateSyncMetadata(ctx, sm); err != nil {
			return nil, fmt.Errorf("failed to update sync metadata: %w", err)
		}

		// Clear synced changes from tracker
		if err := m.changeTracker.ClearChangesForDevice(ctx, deviceID, maxLSN); err != nil {
			// Log error but don't fail sync
		}
	}

	return messages, nil
}

// syncIncomingPolling syncs incoming messages using the old polling-based approach
func (m *Manager) syncIncomingPolling(ctx context.Context, deviceID string, limit int) ([]models.Message, error) {
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


