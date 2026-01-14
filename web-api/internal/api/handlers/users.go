package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"posduif/web-api/internal/database"
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

	// Get current user ID from X-User-ID header
	excludeUserID := r.Header.Get("X-User-ID")

	users, err := h.db.GetAllUsers(r.Context(), excludeUserID)
	if err != nil {
		http.Error(w, "Failed to get users", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

// GetAvailableWebUsers returns list of web users for login screen (public endpoint)
func (h *UsersHandler) GetAvailableWebUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	users, err := h.db.GetWebUsers(r.Context())
	if err != nil {
		// Check if it's a database connection error
		if strings.Contains(err.Error(), "connection refused") || 
		   strings.Contains(err.Error(), "dial") ||
		   strings.Contains(err.Error(), "connect") {
			log.Printf("[USERS] Database connection error: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusServiceUnavailable)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"error": "Database connection unavailable",
				"users": []interface{}{},
			})
			return
		}
		
		log.Printf("[USERS] Error fetching web users: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error": "Failed to fetch users",
			"users": []interface{}{},
		})
		return
	}

	// Return just usernames for simplicity, or full user objects
	// Using full user objects so frontend can display more info if needed
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}
