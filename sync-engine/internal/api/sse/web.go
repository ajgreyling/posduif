package sse

import (
	"fmt"
	"net/http"
	"time"

	"posduif/sync-engine/internal/api/middleware"
	"posduif/sync-engine/internal/database"
)

type WebSSEHandler struct {
	db *database.DB
}

func NewWebSSEHandler(db *database.DB) *WebSSEHandler {
	return &WebSSEHandler{db: db}
}

func (h *WebSSEHandler) HandleSSE(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Path[len("/sse/web/"):]
	if userID == "" {
		http.Error(w, "User ID required", http.StatusBadRequest)
		return
	}

	// Verify user ID matches authenticated user
	authUserID, ok := middleware.GetUserID(r.Context())
	if !ok || authUserID != userID {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
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
	fmt.Fprintf(w, "event: connected\ndata: {\"user_id\":\"%s\"}\n\n", userID)
	flusher.Flush()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Send ping to keep connection alive
			fmt.Fprintf(w, ": ping\n\n")
			flusher.Flush()
		case <-time.After(5 * time.Second):
			// Check for new messages and send events
			count, err := h.db.GetUnreadCount(ctx, userID)
			if err == nil && count > 0 {
				eventData := fmt.Sprintf(`{"type":"new_message","unread_count":%d}`, count)
				fmt.Fprintf(w, "event: new_message\ndata: %s\n\n", eventData)
				flusher.Flush()
			}
		}
	}
}
