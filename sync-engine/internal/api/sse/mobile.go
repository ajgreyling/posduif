package sse

import (
	"fmt"
	"net/http"
	"time"

	"posduif/sync-engine/internal/database"
)

type MobileSSEHandler struct {
	db *database.DB
}

func NewMobileSSEHandler(db *database.DB) *MobileSSEHandler {
	return &MobileSSEHandler{db: db}
}

func (h *MobileSSEHandler) HandleSSE(w http.ResponseWriter, r *http.Request) {
	deviceID := r.URL.Path[len("/sse/mobile/"):]
	if deviceID == "" {
		http.Error(w, "Device ID required", http.StatusBadRequest)
		return
	}

	// Verify device ID matches header
	headerDeviceID := r.Header.Get("X-Device-ID")
	if headerDeviceID != deviceID {
		http.Error(w, "Device ID mismatch", http.StatusBadRequest)
		return
	}

	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		return
	}

	ctx := r.Context()
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	// Send initial connection message
	fmt.Fprintf(w, "event: connected\ndata: {\"device_id\":\"%s\"}\n\n", deviceID)
	flusher.Flush()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Send ping to keep connection alive
			fmt.Fprintf(w, ": ping\n\n")
			flusher.Flush()
		case <-time.After(30 * time.Second):
			// Check for new messages and send events
			messages, err := h.db.GetPendingMessagesForDevice(ctx, deviceID, 10)
			if err == nil && len(messages) > 0 {
				for _, msg := range messages {
					eventData := fmt.Sprintf(`{"type":"new_message","message_id":"%s"}`, msg.ID)
					fmt.Fprintf(w, "event: message\ndata: %s\n\n", eventData)
					flusher.Flush()
				}
			}
		}
	}
}
