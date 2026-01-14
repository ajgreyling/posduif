package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
	"posduif/sync-engine/internal/sync"
)

type SyncHandler struct {
	db      *database.DB
	manager *sync.Manager
}

func NewSyncHandler(db *database.DB, manager *sync.Manager) *SyncHandler {
	return &SyncHandler{
		db:      db,
		manager: manager,
	}
}

func (h *SyncHandler) GetIncoming(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		http.Error(w, "Device ID required", http.StatusBadRequest)
		return
	}

	limit := 100
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	messages, err := h.manager.SyncIncoming(r.Context(), deviceID, limit)
	if err != nil {
		http.Error(w, "Failed to get messages", http.StatusInternalServerError)
		return
	}

	// Get all users for sync (to sync last_message_sent)
	users, err := h.db.GetUsers(r.Context(), models.UserFilter{})
	if err != nil {
		// Log error but don't fail sync
		users = []models.User{}
	}

	response := models.SyncIncomingResponse{
		Messages:      messages,
		Users:         users,
		Compressed:    false,
		SyncTimestamp: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *SyncHandler) UploadOutgoing(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		http.Error(w, "Device ID required", http.StatusBadRequest)
		return
	}

	var req models.SyncOutgoingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	syncedCount := 0
	failedCount := 0
	var failedMessages []models.FailedMessage

	for _, msg := range req.Messages {
		if err := h.db.CreateMessage(r.Context(), &msg); err != nil {
			failedCount++
			failedMessages = append(failedMessages, models.FailedMessage{
				MessageID: msg.ID,
				Error:     err.Error(),
			})
		} else {
			syncedCount++
			// Update sender's last_message_sent
			sender, err := h.db.GetUserByID(r.Context(), msg.SenderID)
			if err == nil {
				sender.LastMessageSent = &msg.Content
				h.db.UpdateUser(r.Context(), sender)
			}
		}
	}

	response := models.SyncOutgoingResponse{
		SyncedCount:    syncedCount,
		FailedCount:    failedCount,
		FailedMessages: failedMessages,
		SyncTimestamp:  time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *SyncHandler) GetSyncStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		http.Error(w, "Device ID required", http.StatusBadRequest)
		return
	}

	sm, err := h.db.GetSyncMetadata(r.Context(), deviceID)
	if err != nil {
		// Create default sync metadata if not exists
		sm = &models.SyncMetadata{
			DeviceID:             deviceID,
			PendingOutgoingCount: 0,
			SyncStatus:           "idle",
		}
		h.db.UpdateSyncMetadata(r.Context(), sm)
	}

	status := models.SyncStatus{
		DeviceID:             sm.DeviceID,
		LastSyncTimestamp:    sm.LastSyncTimestamp,
		PendingOutgoingCount: sm.PendingOutgoingCount,
		SyncStatus:           sm.SyncStatus,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}


