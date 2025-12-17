package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"posduif/sync-engine/internal/api/middleware"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
	"posduif/sync-engine/internal/redis"
)

type MessagesHandler struct {
	db        *database.DB
	publisher *redis.Publisher
}

func NewMessagesHandler(db *database.DB, publisher *redis.Publisher) *MessagesHandler {
	return &MessagesHandler{
		db:        db,
		publisher: publisher,
	}
}

func (h *MessagesHandler) CreateMessage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req models.CreateMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate content
	if strings.TrimSpace(req.Content) == "" {
		http.Error(w, "Message content cannot be empty", http.StatusBadRequest)
		return
	}

	// Verify recipient exists
	_, err := h.db.GetUserByID(r.Context(), req.RecipientID)
	if err != nil {
		http.Error(w, "Recipient not found", http.StatusNotFound)
		return
	}

	// Create message
	msg := &models.Message{
		SenderID:    userID,
		RecipientID: req.RecipientID,
		Content:     req.Content,
		Status:      "pending_sync",
	}

	if err := h.db.CreateMessage(r.Context(), msg); err != nil {
		http.Error(w, "Failed to create message", http.StatusInternalServerError)
		return
	}

	// Publish event
	h.publisher.PublishNewMessage(r.Context(), msg.ID, req.RecipientID, 0)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(msg)
}

func (h *MessagesHandler) ListMessages(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	filter := models.MessageFilter{
		RecipientID: &userID,
		Limit:       50,
		Offset:      0,
	}

	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if limit, err := strconv.Atoi(limitStr); err == nil && limit > 0 {
			filter.Limit = limit
		}
	}

	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if offset, err := strconv.Atoi(offsetStr); err == nil && offset >= 0 {
			filter.Offset = offset
		}
	}

	if status := r.URL.Query().Get("status"); status != "" {
		filter.Status = &status
	}

	messages, err := h.db.GetMessages(r.Context(), filter)
	if err != nil {
		http.Error(w, "Failed to get messages", http.StatusInternalServerError)
		return
	}

	response := models.MessageListResponse{
		Messages: messages,
		Total:    len(messages),
		Limit:    filter.Limit,
		Offset:   filter.Offset,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *MessagesHandler) GetUnreadCount(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	count, err := h.db.GetUnreadCount(r.Context(), userID)
	if err != nil {
		http.Error(w, "Failed to get unread count", http.StatusInternalServerError)
		return
	}

	response := map[string]int{
		"unread_count": count,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *MessagesHandler) GetMessage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	messageID := r.URL.Path[len("/api/messages/"):]
	if messageID == "" {
		http.Error(w, "Message ID required", http.StatusBadRequest)
		return
	}

	// Get message (simplified - in production, verify user has access)
	messages, err := h.db.GetMessages(r.Context(), models.MessageFilter{
		Limit: 1,
	})
	if err != nil || len(messages) == 0 {
		http.Error(w, "Message not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(messages[0])
}

func (h *MessagesHandler) MarkAsRead(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 4 {
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	messageID := pathParts[3]
	if err := h.db.UpdateMessageStatus(r.Context(), messageID, "read"); err != nil {
		http.Error(w, "Failed to update message", http.StatusInternalServerError)
		return
	}

	response := map[string]string{
		"id":     messageID,
		"status": "read",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
