package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
)

type SyncHandler struct {
	db *database.DB
}

func NewSyncHandler(db *database.DB) *SyncHandler {
	return &SyncHandler{db: db}
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

	messages, err := h.db.GetPendingMessagesForDevice(r.Context(), deviceID, limit)
	if err != nil {
		http.Error(w, "Failed to get messages", http.StatusInternalServerError)
		return
	}

	// Update message status to synced
	for _, msg := range messages {
		h.db.UpdateMessageStatus(r.Context(), msg.ID, "synced")
	}

	response := models.SyncIncomingResponse{
		Messages:      messages,
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
