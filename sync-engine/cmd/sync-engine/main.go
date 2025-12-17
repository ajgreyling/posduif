package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"posduif/sync-engine/internal/api/handlers"
	"posduif/sync-engine/internal/api/middleware"
	"posduif/sync-engine/internal/api/sse"
	"posduif/sync-engine/internal/config"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/enrollment"
	"posduif/sync-engine/internal/redis"
)

var (
	configPath = flag.String("config", "config/config.yaml", "Path to configuration file")
)

func main() {
	flag.Parse()

	// Load configuration
	cfg, err := config.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize database
	db, err := database.NewDB(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Initialize Redis
	redisClient, err := redis.NewClient(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	defer redisClient.Close()

	// Initialize services
	enrollmentService := enrollment.NewService(db, cfg)
	redisPublisher := redis.NewPublisher(redisClient.GetClient(), cfg)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(db, cfg.Auth.JWTSecret, cfg.Auth.JWTExpiration)
	usersHandler := handlers.NewUsersHandler(db)
	messagesHandler := handlers.NewMessagesHandler(db, redisPublisher)
	enrollmentHandler := handlers.NewEnrollmentHandler(enrollmentService)
	syncHandler := handlers.NewSyncHandler(db)
	mobileSSEHandler := sse.NewMobileSSEHandler(db)
	webSSEHandler := sse.NewWebSSEHandler(db)

	// Initialize middleware
	authMiddleware := middleware.NewAuthMiddleware(cfg.Auth.JWTSecret)
	corsMiddleware := middleware.NewCORSMiddleware(
		cfg.CORS.AllowedOrigins,
		cfg.CORS.AllowedMethods,
		cfg.CORS.AllowedHeaders,
	)
	loggingMiddleware := middleware.NewLoggingMiddleware()

	// Set up router
	router := mux.NewRouter()

	// Apply global middleware
	router.Use(loggingMiddleware.Middleware)
	router.Use(corsMiddleware.Middleware)

	// Health check endpoint
	router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	}).Methods("GET")

	// API routes
	api := router.PathPrefix("/api").Subrouter()

	// Authentication (no auth required)
	api.HandleFunc("/auth/login", authHandler.Login).Methods("POST")

	// Protected routes (require authentication)
	protected := api.PathPrefix("").Subrouter()
	protected.Use(authMiddleware.Middleware)

	// Users
	protected.HandleFunc("/users", usersHandler.ListUsers).Methods("GET")
	protected.HandleFunc("/users/{id}", usersHandler.GetUser).Methods("GET")

	// Messages
	protected.HandleFunc("/messages", messagesHandler.CreateMessage).Methods("POST")
	protected.HandleFunc("/messages", messagesHandler.ListMessages).Methods("GET")
	protected.HandleFunc("/messages/unread-count", messagesHandler.GetUnreadCount).Methods("GET")
	protected.HandleFunc("/messages/{id}", messagesHandler.GetMessage).Methods("GET")
	protected.HandleFunc("/messages/{id}/read", messagesHandler.MarkAsRead).Methods("PUT")

	// Enrollment
	protected.HandleFunc("/enrollment/create", enrollmentHandler.CreateEnrollment).Methods("POST")
	api.HandleFunc("/enrollment/{token}", enrollmentHandler.GetEnrollment).Methods("GET")
	api.HandleFunc("/enrollment/complete", enrollmentHandler.CompleteEnrollment).Methods("POST")
	api.HandleFunc("/app-instructions", enrollmentHandler.GetAppInstructions).Methods("GET")

	// Sync (device ID based auth)
	api.HandleFunc("/sync/incoming", syncHandler.GetIncoming).Methods("GET")
	api.HandleFunc("/sync/outgoing", syncHandler.UploadOutgoing).Methods("POST")
	api.HandleFunc("/sync/status", syncHandler.GetSyncStatus).Methods("GET")

	// SSE endpoints
	protected.HandleFunc("/sse/web/{user_id}", webSSEHandler.HandleSSE).Methods("GET")
	api.HandleFunc("/sse/mobile/{device_id}", mobileSSEHandler.HandleSSE).Methods("GET")

	// Set up HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.SSE.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	_, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint

		log.Println("Shutting down server...")
		cancel()

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()

		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Printf("Server shutdown error: %v", err)
		}
	}()

	log.Printf("Starting sync engine on :%d", cfg.SSE.Port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}

	log.Println("Server stopped")
}
