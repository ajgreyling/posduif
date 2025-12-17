package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"posduif/sync-engine/internal/api/handlers"
	"posduif/sync-engine/internal/api/middleware"
	"posduif/sync-engine/internal/config"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/enrollment"
	"posduif/sync-engine/internal/redis"
)

func main() {
	configPath := flag.String("config", "config/config.yaml", "Path to configuration file")
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
	enrollmentHandler := handlers.NewEnrollmentHandler(enrollmentService)
	messagesHandler := handlers.NewMessagesHandler(db, redisPublisher)
	syncHandler := handlers.NewSyncHandler(db)
	usersHandler := handlers.NewUsersHandler(db)

	// Initialize middleware
	authMiddleware := middleware.NewAuthMiddleware(cfg.Auth.JWTSecret)
	corsMiddleware := middleware.NewCORSMiddleware(
		cfg.CORS.AllowedOrigins,
		cfg.CORS.AllowedMethods,
		cfg.CORS.AllowedHeaders,
	)
	loggingMiddleware := middleware.NewLoggingMiddleware()

	// Setup router
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Public endpoints (no auth required)
	mux.HandleFunc("/api/auth/login", authHandler.Login)
	mux.HandleFunc("/api/enrollment/", func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		if strings.HasSuffix(path, "/complete") {
			enrollmentHandler.CompleteEnrollment(w, r)
		} else {
			// Extract token from path: /api/enrollment/{token}
			enrollmentHandler.GetEnrollment(w, r)
		}
	})

	// Protected endpoints (require auth)
	protectedMux := http.NewServeMux()
	protectedMux.HandleFunc("/api/enrollment/create", enrollmentHandler.CreateEnrollment)
	protectedMux.HandleFunc("/api/messages", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			messagesHandler.ListMessages(w, r)
		case http.MethodPost:
			messagesHandler.CreateMessage(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})
	protectedMux.HandleFunc("/api/messages/", func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		if strings.HasSuffix(path, "/read") {
			messagesHandler.MarkAsRead(w, r)
		} else {
			messagesHandler.GetMessage(w, r)
		}
	})
	protectedMux.HandleFunc("/api/users", usersHandler.ListUsers)
	protectedMux.HandleFunc("/api/users/", usersHandler.GetUser)

	// Device-authenticated endpoints (require X-Device-ID header)
	deviceMux := http.NewServeMux()
	deviceMux.HandleFunc("/api/app-instructions", enrollmentHandler.GetAppInstructions)
	deviceMux.HandleFunc("/api/sync/incoming", syncHandler.GetIncoming)
	deviceMux.HandleFunc("/api/sync/outgoing", syncHandler.UploadOutgoing)
	deviceMux.HandleFunc("/api/sync/status", syncHandler.GetSyncStatus)

	// Widget endpoints (public, for remote widgets)
	mux.HandleFunc("/widgets/", handlers.ServeWidget)

	// Apply middleware chain
	handler := loggingMiddleware.Middleware(
		corsMiddleware.Middleware(
			http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				path := r.URL.Path
				
				// Log routing decision for debugging
				ngrokForwardedHost := r.Header.Get("X-Forwarded-Host")
				if ngrokForwardedHost != "" {
					log.Printf("[ROUTER] Routing request via ngrok - Path: %s, Host: %s", path, ngrokForwardedHost)
				}

				// Route to appropriate handler based on path
				if strings.HasPrefix(path, "/api/enrollment/create") ||
					strings.HasPrefix(path, "/api/messages") ||
					strings.HasPrefix(path, "/api/users") {
					// Protected routes - require auth
					authMiddleware.Middleware(protectedMux).ServeHTTP(w, r)
				} else if strings.HasPrefix(path, "/api/app-instructions") ||
					strings.HasPrefix(path, "/api/sync/") {
					// Device-authenticated routes - require X-Device-ID
					log.Printf("[ROUTER] Routing to deviceMux for path: %s", path)
					deviceMux.ServeHTTP(w, r)
				} else {
					// Public routes
					mux.ServeHTTP(w, r)
				}
			}),
		),
	)

	// Start server
	addr := fmt.Sprintf(":%d", cfg.SSE.Port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	go func() {
		log.Printf("Starting sync engine on %s", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
