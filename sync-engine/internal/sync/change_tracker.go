package sync

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
)

// ChangeTracker tracks WAL changes per device and filters them by recipient
type ChangeTracker struct {
	db          *database.DB
	changes     map[string][]*WALChange // deviceID -> changes
	changesLock sync.RWMutex
}

// NewChangeTracker creates a new change tracker
func NewChangeTracker(db *database.DB) *ChangeTracker {
	return &ChangeTracker{
		db:      db,
		changes: make(map[string][]*WALChange),
	}
}

// AddChange adds a WAL change to the tracker, filtering by recipient
// and excluding sender devices to prevent sync loops
func (ct *ChangeTracker) AddChange(ctx context.Context, change *WALChange) error {
	// Only process changes for the messages table
	if change.Table != "messages" {
		return nil
	}

	// Only process INSERT and UPDATE operations
	if change.Operation != "INSERT" && change.Operation != "UPDATE" {
		return nil
	}

	// Extract recipient_id from the change columns
	recipientID, ok := change.Columns["recipient_id"]
	if !ok {
		// For UPDATE operations, check old columns if new columns don't have it
		if change.Operation == "UPDATE" {
			recipientID, ok = change.OldColumns["recipient_id"]
		}
		if !ok {
			return nil // No recipient_id, skip
		}
	}

	recipientIDStr, ok := recipientID.(string)
	if !ok {
		return nil // Invalid recipient_id type
	}

	// Extract sender_id from the change columns to prevent sync loops
	// For INSERT: sender_id is in Columns
	// For UPDATE: check both Columns (new) and OldColumns (old) to handle sender changes
	var senderIDStr string
	var oldSenderIDStr string
	
	// Get new sender_id (for INSERT and UPDATE)
	senderID, ok := change.Columns["sender_id"]
	if ok {
		if sid, ok := senderID.(string); ok {
			senderIDStr = sid
		}
	}
	
	// For UPDATE operations, also get old sender_id to handle sender changes
	if change.Operation == "UPDATE" {
		if oldSenderID, ok := change.OldColumns["sender_id"]; ok {
			if sid, ok := oldSenderID.(string); ok {
				oldSenderIDStr = sid
			}
		}
	}
	
	// If no sender_id found in either location, skip this change
	if senderIDStr == "" && oldSenderIDStr == "" {
		return nil
	}

	// Find all devices for this recipient
	recipientDevices, err := ct.getDevicesForRecipient(ctx, recipientIDStr)
	if err != nil {
		return fmt.Errorf("failed to get devices for recipient: %w", err)
	}

	// Find all devices for the sender(s) to exclude them from receiving their own messages
	// For UPDATE operations, exclude devices for both old and new sender (if different)
	senderDeviceMap := make(map[string]bool)
	
	// Add devices for new sender
	if senderIDStr != "" {
		senderDevices, err := ct.getDevicesForSender(ctx, senderIDStr)
		if err != nil {
			return fmt.Errorf("failed to get devices for sender: %w", err)
		}
		for _, deviceID := range senderDevices {
			senderDeviceMap[deviceID] = true
		}
	}
	
	// Add devices for old sender (if different from new sender)
	if oldSenderIDStr != "" && oldSenderIDStr != senderIDStr {
		oldSenderDevices, err := ct.getDevicesForSender(ctx, oldSenderIDStr)
		if err != nil {
			return fmt.Errorf("failed to get devices for old sender: %w", err)
		}
		for _, deviceID := range oldSenderDevices {
			senderDeviceMap[deviceID] = true
		}
	}

	// Filter out sender devices from recipient devices to prevent sync loops
	filteredDevices := make([]string, 0)
	for _, deviceID := range recipientDevices {
		if !senderDeviceMap[deviceID] {
			filteredDevices = append(filteredDevices, deviceID)
		}
	}

	// Add change to each filtered device's queue
	ct.changesLock.Lock()
	defer ct.changesLock.Unlock()

	for _, deviceID := range filteredDevices {
		if ct.changes[deviceID] == nil {
			ct.changes[deviceID] = make([]*WALChange, 0)
		}
		ct.changes[deviceID] = append(ct.changes[deviceID], change)
	}

	return nil
}

// GetChangesForDevice returns all pending changes for a device since the last synced LSN
func (ct *ChangeTracker) GetChangesForDevice(ctx context.Context, deviceID string, limit int) ([]*WALChange, error) {
	// Get device's last synced LSN
	sm, err := ct.db.GetSyncMetadata(ctx, deviceID)
	if err != nil {
		return nil, fmt.Errorf("failed to get sync metadata: %w", err)
	}

	ct.changesLock.RLock()
	defer ct.changesLock.RUnlock()

	deviceChanges := ct.changes[deviceID]
	if deviceChanges == nil {
		return []*WALChange{}, nil
	}

	// Filter changes that are newer than last synced LSN
	filteredChanges := make([]*WALChange, 0)
	for _, change := range deviceChanges {
		// If no LSN is set, include all changes
		if sm.LastSyncedLSN == nil || *sm.LastSyncedLSN == "" {
			filteredChanges = append(filteredChanges, change)
			continue
		}

		// Compare LSNs
		// Convert string to models.LSN
		lastLSN, err := models.ParseLSN(*sm.LastSyncedLSN)
		if err != nil {
			// If conversion fails, include the change
			filteredChanges = append(filteredChanges, change)
			continue
		}
		
		if change.LSN > lastLSN {
			filteredChanges = append(filteredChanges, change)
		}
	}

	// Limit results
	if limit > 0 && len(filteredChanges) > limit {
		filteredChanges = filteredChanges[:limit]
	}

	return filteredChanges, nil
}

// ClearChangesForDevice clears changes for a device after successful sync
func (ct *ChangeTracker) ClearChangesForDevice(ctx context.Context, deviceID string, syncedLSN models.LSN) error {
	ct.changesLock.Lock()
	defer ct.changesLock.Unlock()

	// Remove changes up to and including the synced LSN
	deviceChanges := ct.changes[deviceID]
	if deviceChanges == nil {
		return nil
	}

	filteredChanges := make([]*WALChange, 0)
	for _, change := range deviceChanges {
		if change.LSN > syncedLSN {
			filteredChanges = append(filteredChanges, change)
		}
	}

	ct.changes[deviceID] = filteredChanges
	return nil
}

// getDevicesForRecipient gets all device IDs for a recipient user
func (ct *ChangeTracker) getDevicesForRecipient(ctx context.Context, recipientID string) ([]string, error) {
	// Query users table to find device_id for the recipient
	// We need to access the pool through a method or add a method to DB
	// For now, let's add a helper method to database.DB
	user, err := ct.db.GetUserByID(ctx, recipientID)
	if err != nil {
		if err == pgx.ErrNoRows {
			// No device found for this recipient (might be a web user)
			return []string{}, nil
		}
		return nil, err
	}

	if user.DeviceID == nil || *user.DeviceID == "" {
		return []string{}, nil
	}

	return []string{*user.DeviceID}, nil
}

// getDevicesForSender gets all device IDs for a sender user
// This is used to exclude the sender's device(s) from receiving their own messages
func (ct *ChangeTracker) getDevicesForSender(ctx context.Context, senderID string) ([]string, error) {
	user, err := ct.db.GetUserByID(ctx, senderID)
	if err != nil {
		if err == pgx.ErrNoRows {
			// No user found (shouldn't happen, but handle gracefully)
			return []string{}, nil
		}
		return nil, err
	}

	// If sender is a web user (no device_id), return empty list
	if user.DeviceID == nil || *user.DeviceID == "" {
		return []string{}, nil
	}

	return []string{*user.DeviceID}, nil
}

// ConvertWALChangeToMessage converts a WAL change to a Message model
func ConvertWALChangeToMessage(change *WALChange) (*models.Message, error) {
	if change.Operation != "INSERT" && change.Operation != "UPDATE" {
		return nil, fmt.Errorf("unsupported operation: %s", change.Operation)
	}

	msg := &models.Message{}

	// Extract fields from change columns
	if id, ok := change.Columns["id"].(string); ok {
		msg.ID = id
	}
	if senderID, ok := change.Columns["sender_id"].(string); ok {
		msg.SenderID = senderID
	}
	if recipientID, ok := change.Columns["recipient_id"].(string); ok {
		msg.RecipientID = recipientID
	}
	if content, ok := change.Columns["content"].(string); ok {
		msg.Content = content
	}
	if status, ok := change.Columns["status"].(string); ok {
		msg.Status = status
	} else {
		msg.Status = "pending_sync"
	}

	// Extract timestamps
	if createdAt, ok := change.Columns["created_at"].(time.Time); ok {
		msg.CreatedAt = createdAt
	} else {
		msg.CreatedAt = change.CommitTime
	}

	if updatedAt, ok := change.Columns["updated_at"].(time.Time); ok {
		msg.UpdatedAt = updatedAt
	} else {
		msg.UpdatedAt = change.CommitTime
	}

	if syncedAt, ok := change.Columns["synced_at"].(time.Time); ok {
		msg.SyncedAt = &syncedAt
	}
	if readAt, ok := change.Columns["read_at"].(time.Time); ok {
		msg.ReadAt = &readAt
	}

	return msg, nil
}
