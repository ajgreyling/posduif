package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
)

type UsersHandler struct {
	db *database.DB
}

func NewUsersHandler(db *database.DB) *UsersHandler {
	return &UsersHandler{db: db}
}

func (h *UsersHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	filter := models.UserFilter{
		Filter: r.URL.Query().Get("filter"),
	}

	if statusStr := r.URL.Query().Get("status"); statusStr != "" {
		status, err := strconv.ParseBool(statusStr)
		if err == nil {
			filter.Status = &status
		}
	}

	users, err := h.db.GetUsers(r.Context(), filter)
	if err != nil {
		http.Error(w, "Failed to get users", http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"users": users,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *UsersHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.URL.Path[len("/api/users/"):]
	if userID == "" {
		http.Error(w, "User ID required", http.StatusBadRequest)
		return
	}

	user, err := h.db.GetUserByID(r.Context(), userID)
	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}


