package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"posduif/sync-engine/internal/api/middleware"
	"posduif/sync-engine/internal/enrollment"
	"posduif/sync-engine/internal/models"
)

type EnrollmentHandler struct {
	service *enrollment.Service
}

func NewEnrollmentHandler(service *enrollment.Service) *EnrollmentHandler {
	return &EnrollmentHandler{service: service}
}

func (h *EnrollmentHandler) CreateEnrollment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	response, err := h.service.CreateEnrollment(r.Context(), userID)
	if err != nil {
		log.Printf("[ENROLLMENT] Error creating enrollment: %v", err)
		http.Error(w, "Failed to create enrollment", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

func (h *EnrollmentHandler) GetEnrollment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	token := r.URL.Path[len("/api/enrollment/"):]
	if token == "" {
		http.Error(w, "Token required", http.StatusBadRequest)
		return
	}

	log.Printf("[ENROLLMENT] GetEnrollment called for token: %s", token)
	details, err := h.service.GetEnrollment(r.Context(), token)
	if err != nil {
		log.Printf("[ENROLLMENT] Error getting enrollment details: %v", err)
		http.Error(w, "Enrollment token not found", http.StatusNotFound)
		return
	}

	if !details.Valid {
		log.Printf("[ENROLLMENT] Token is invalid or expired: %s", token)
		http.Error(w, "Enrollment token expired or already used", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(details)
}

func (h *EnrollmentHandler) CompleteEnrollment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	log.Printf("[ENROLLMENT] CompleteEnrollment called")
	var req models.CompleteEnrollmentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[ENROLLMENT] Error decoding request: %v", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	log.Printf("[ENROLLMENT] Request - token: %s, device_id: %s", req.Token, req.DeviceID)

	result, err := h.service.CompleteEnrollment(r.Context(), &req)
	if err != nil {
		log.Printf("[ENROLLMENT] Error completing enrollment: %v", err)
		log.Printf("[ENROLLMENT] Error details - token: %s, device_id: %s", req.Token, req.DeviceID)
		
		if strings.Contains(err.Error(), "not found") {
			http.Error(w, "Enrollment token not found or expired", http.StatusNotFound)
		} else if strings.Contains(err.Error(), "already used") {
			http.Error(w, "Enrollment token already used", http.StatusBadRequest)
		} else if strings.Contains(err.Error(), "unique") || strings.Contains(err.Error(), "duplicate") {
			http.Error(w, "Device already enrolled", http.StatusConflict)
		} else {
			http.Error(w, "Failed to complete enrollment: "+err.Error(), http.StatusInternalServerError)
		}
		return
	}

	log.Printf("[ENROLLMENT] Enrollment completed successfully - user_id: %s, device_id: %s", result.UserID, result.DeviceID)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (h *EnrollmentHandler) GetAppInstructions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	deviceID := r.Header.Get("X-Device-ID")
	if deviceID == "" {
		log.Printf("[ENROLLMENT] GetAppInstructions called without X-Device-ID header")
		log.Printf("[ENROLLMENT] Request headers: %v", r.Header)
		http.Error(w, "Device ID required", http.StatusUnauthorized)
		return
	}

	// Log request details for debugging
	ngrokForwardedHost := r.Header.Get("X-Forwarded-Host")
	ngrokForwardedProto := r.Header.Get("X-Forwarded-Proto")
	log.Printf("[ENROLLMENT] GetAppInstructions called for device_id: %s", deviceID)
	if ngrokForwardedHost != "" {
		log.Printf("[ENROLLMENT] Request via ngrok - Host: %s, Proto: %s", ngrokForwardedHost, ngrokForwardedProto)
	}
	log.Printf("[ENROLLMENT] Request path: %s, Method: %s", r.URL.Path, r.Method)
	
	instructions, err := h.service.GetAppInstructions(r.Context(), deviceID)
	if err != nil {
		log.Printf("[ENROLLMENT] Error getting app instructions: %v", err)
		log.Printf("[ENROLLMENT] Error details - device_id: %s, error: %v", deviceID, err)
		http.Error(w, "Device not enrolled", http.StatusNotFound)
		return
	}

	log.Printf("[ENROLLMENT] App instructions retrieved successfully for device_id: %s", deviceID)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(instructions)
}

// ServeWidget serves remote widget JSON files
func ServeWidget(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract widget name from path (e.g., /widgets/inbox.json -> inbox)
	widgetName := r.URL.Path
	if strings.HasPrefix(widgetName, "/widgets/") {
		widgetName = widgetName[len("/widgets/"):]
	}
	widgetName = strings.TrimSuffix(widgetName, ".json")
	
	if widgetName == "" {
		http.Error(w, "Widget name required", http.StatusBadRequest)
		return
	}

	log.Printf("[WIDGET] Serving widget: %s", widgetName)

	// Define widget JSON structures
	var widgetData map[string]interface{}

	switch widgetName {
	case "inbox":
		widgetData = map[string]interface{}{
			"type": "inbox_screen",
			"widget": "InboxScreen",
			"properties": map[string]interface{}{
				"title": "Messages",
			},
		}
	case "compose":
		widgetData = map[string]interface{}{
			"type": "compose_screen",
			"widget": "ComposeScreen",
			"properties": map[string]interface{}{
				"title": "Compose Message",
			},
		}
	case "message_detail":
		widgetData = map[string]interface{}{
			"type": "message_detail_screen",
			"widget": "MessageDetailScreen",
			"properties": map[string]interface{}{
				"title": "Message",
			},
		}
	default:
		log.Printf("[WIDGET] Widget not found: %s", widgetName)
		http.Error(w, "Widget not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(widgetData)
}
