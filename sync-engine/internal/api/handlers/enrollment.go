package handlers

import (
	"encoding/json"
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

	details, err := h.service.GetEnrollment(r.Context(), token)
	if err != nil {
		http.Error(w, "Enrollment token not found", http.StatusNotFound)
		return
	}

	if !details.Valid {
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

	var req models.CompleteEnrollmentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	result, err := h.service.CompleteEnrollment(r.Context(), &req)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			http.Error(w, "Enrollment token not found or expired", http.StatusNotFound)
		} else {
			http.Error(w, "Failed to complete enrollment", http.StatusInternalServerError)
		}
		return
	}

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
		http.Error(w, "Device ID required", http.StatusUnauthorized)
		return
	}

	instructions, err := h.service.GetAppInstructions(r.Context(), deviceID)
	if err != nil {
		http.Error(w, "Device not enrolled", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(instructions)
}
