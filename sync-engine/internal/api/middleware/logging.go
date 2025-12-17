package middleware

import (
	"log"
	"net/http"
	"time"
)

type LoggingMiddleware struct{}

func NewLoggingMiddleware() *LoggingMiddleware {
	return &LoggingMiddleware{}
}

func (m *LoggingMiddleware) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Log ngrok-specific headers for debugging
		ngrokForwardedHost := r.Header.Get("X-Forwarded-Host")
		ngrokForwardedProto := r.Header.Get("X-Forwarded-Proto")
		ngrokForwardedFor := r.Header.Get("X-Forwarded-For")
		deviceID := r.Header.Get("X-Device-ID")
		userAgent := r.Header.Get("User-Agent")
		
		// Wrap response writer to capture status code
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(wrapped, r)

		duration := time.Since(start)
		
		// Enhanced logging with ngrok headers
		if ngrokForwardedHost != "" || ngrokForwardedProto != "" {
			log.Printf(
				"[NGROK] %s %s %d %v | Host: %s | Proto: %s | Forwarded-For: %s | Device-ID: %s | User-Agent: %s",
				r.Method,
				r.URL.Path,
				wrapped.statusCode,
				duration,
				ngrokForwardedHost,
				ngrokForwardedProto,
				ngrokForwardedFor,
				deviceID,
				userAgent,
			)
		} else {
			log.Printf(
				"%s %s %d %v | Device-ID: %s",
				r.Method,
				r.URL.Path,
				wrapped.statusCode,
				duration,
				deviceID,
			)
		}
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}
