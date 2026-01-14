package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"posduif/web-api/internal/database"
)

type AuthHandler struct {
	db *database.DB
}

func NewAuthHandler(db *database.DB) *AuthHandler {
	return &AuthHandler{db: db}
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Username string `json:"username"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Get user by username, or create if doesn't exist (no password check)
	user, err := h.db.GetUserByUsername(r.Context(), req.Username)
	if err != nil {
		// Check if it's a database connection error
		if strings.Contains(err.Error(), "connection refused") || 
		   strings.Contains(err.Error(), "dial") ||
		   strings.Contains(err.Error(), "connect") {
			log.Printf("[AUTH] Database connection error for user '%s': %v", req.Username, err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusServiceUnavailable)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"error": "Database connection unavailable. Please try again later.",
			})
			return
		}
		
		// User doesn't exist, create it (auto-registration for web users)
		log.Printf("[AUTH] User '%s' not found, creating new user", req.Username)
		user, err = h.db.CreateUser(r.Context(), req.Username)
		if err != nil {
			// Check if creation failed due to database connection
			if strings.Contains(err.Error(), "connection refused") || 
			   strings.Contains(err.Error(), "dial") ||
			   strings.Contains(err.Error(), "connect") {
				log.Printf("[AUTH] Database connection error while creating user '%s': %v", req.Username, err)
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusServiceUnavailable)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"error": "Database connection unavailable. Please try again later.",
				})
				return
			}
			
			log.Printf("[AUTH] Failed to create user '%s': %v", req.Username, err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"error": "Failed to create user account",
			})
			return
		}
		log.Printf("[AUTH] Created user '%s' with ID '%s'", req.Username, user.ID)
	}

	// Return user info (in production, would return JWT token)
	response := map[string]interface{}{
		"user_id":  user.ID,
		"username": user.Username,
		"user_type": user.UserType,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
