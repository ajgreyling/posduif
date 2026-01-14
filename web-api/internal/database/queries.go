package database

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"posduif/web-api/internal/config"
	"posduif/web-api/internal/models"
)

type DB struct {
	Pool *pgxpool.Pool
}

func NewDB(cfg *config.Config) (*DB, error) {
	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
		cfg.Postgres.Host,
		cfg.Postgres.Port,
		cfg.Postgres.User,
		cfg.Postgres.Password,
		cfg.Postgres.DB,
	)

	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	return &DB{Pool: pool}, nil
}

func (db *DB) Close() {
	db.Pool.Close()
}

// User queries
func (db *DB) GetUserByUsername(ctx context.Context, username string) (*models.User, error) {
	var user models.User
	query := `SELECT id, username, user_type, device_id, online_status, last_seen,
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at
	          FROM users WHERE username = $1`

	err := db.Pool.QueryRow(ctx, query, username).Scan(
		&user.ID, &user.Username, &user.UserType, &user.DeviceID,
		&user.OnlineStatus, &user.LastSeen, &user.EnrolledAt,
		&user.EnrollmentTokenID, &user.LastMessageSent, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (db *DB) GetAllUsers(ctx context.Context, excludeUserID string) ([]models.User, error) {
	query := `SELECT id, username, user_type, device_id, online_status, last_seen,
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at
	          FROM users`
	args := []interface{}{}
	
	if excludeUserID != "" {
		query += " WHERE id != $1"
		args = append(args, excludeUserID)
	}
	
	query += " ORDER BY updated_at DESC"

	rows, err := db.Pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		err := rows.Scan(
			&user.ID, &user.Username, &user.UserType, &user.DeviceID,
			&user.OnlineStatus, &user.LastSeen, &user.EnrolledAt,
			&user.EnrollmentTokenID, &user.LastMessageSent, &user.CreatedAt, &user.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	return users, rows.Err()
}

// GetWebUsers returns all users with user_type = 'web'
func (db *DB) GetWebUsers(ctx context.Context) ([]models.User, error) {
	query := `SELECT id, username, user_type, device_id, online_status, last_seen,
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at
	          FROM users WHERE user_type = 'web'
	          ORDER BY username ASC`

	rows, err := db.Pool.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		err := rows.Scan(
			&user.ID, &user.Username, &user.UserType, &user.DeviceID,
			&user.OnlineStatus, &user.LastSeen, &user.EnrolledAt,
			&user.EnrollmentTokenID, &user.LastMessageSent, &user.CreatedAt, &user.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	return users, rows.Err()
}

// Message queries
func (db *DB) CreateMessage(ctx context.Context, msg *models.Message) error {
	now := time.Now()
	if msg.ID == "" {
		msg.ID = uuid.New().String()
	}
	if msg.Status == "" {
		msg.Status = "pending_sync"
	}
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = now
	}
	msg.UpdatedAt = now

	query := `INSERT INTO messages (id, sender_id, recipient_id, content, status, 
	          created_at, updated_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7)`

	_, err := db.Pool.Exec(ctx, query,
		msg.ID, msg.SenderID, msg.RecipientID, msg.Content,
		msg.Status, msg.CreatedAt, msg.UpdatedAt,
	)
	if err != nil {
		return err
	}

	// Update sender's last_message_sent
	sender, err := db.GetUserByID(ctx, msg.SenderID)
	if err == nil {
		sender.LastMessageSent = &msg.Content
		db.UpdateUser(ctx, sender)
	}

	return nil
}

func (db *DB) GetUserByID(ctx context.Context, userID string) (*models.User, error) {
	var user models.User
	query := `SELECT id, username, user_type, device_id, online_status, last_seen,
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at
	          FROM users WHERE id = $1`

	err := db.Pool.QueryRow(ctx, query, userID).Scan(
		&user.ID, &user.Username, &user.UserType, &user.DeviceID,
		&user.OnlineStatus, &user.LastSeen, &user.EnrolledAt,
		&user.EnrollmentTokenID, &user.LastMessageSent, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// CreateUser creates a new web user if it doesn't exist
func (db *DB) CreateUser(ctx context.Context, username string) (*models.User, error) {
	userID := uuid.New().String()
	now := time.Now()
	
	query := `INSERT INTO users (id, username, user_type, online_status, created_at, updated_at)
	          VALUES ($1, $2, 'web', true, $3, $4)
	          ON CONFLICT (username) DO UPDATE SET
	          online_status = true, updated_at = $4
	          RETURNING id, username, user_type, device_id, online_status, last_seen,
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at`
	
	var user models.User
	err := db.Pool.QueryRow(ctx, query, userID, username, now, now).Scan(
		&user.ID, &user.Username, &user.UserType, &user.DeviceID,
		&user.OnlineStatus, &user.LastSeen, &user.EnrolledAt,
		&user.EnrollmentTokenID, &user.LastMessageSent, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}
	return &user, nil
}

func (db *DB) UpdateUser(ctx context.Context, user *models.User) error {
	query := `UPDATE users SET 
	          username = $2, user_type = $3, device_id = $4, online_status = $5,
	          last_seen = $6, enrolled_at = $7, enrollment_token_id = $8,
	          last_message_sent = $9, updated_at = NOW()
	          WHERE id = $1`
	
	_, err := db.Pool.Exec(ctx, query,
		user.ID, user.Username, user.UserType, user.DeviceID,
		user.OnlineStatus, user.LastSeen, user.EnrolledAt,
		user.EnrollmentTokenID, user.LastMessageSent,
	)
	return err
}

func (db *DB) GetMessages(ctx context.Context, userID string, limit, offset int) ([]models.Message, error) {
	query := `SELECT id, sender_id, recipient_id, content, status, created_at, 
	          updated_at, synced_at, read_at FROM messages 
	          WHERE sender_id = $1 OR recipient_id = $1
	          ORDER BY created_at DESC LIMIT $2 OFFSET $3`

	rows, err := db.Pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []models.Message
	for rows.Next() {
		var msg models.Message
		err := rows.Scan(
			&msg.ID, &msg.SenderID, &msg.RecipientID, &msg.Content,
			&msg.Status, &msg.CreatedAt, &msg.UpdatedAt,
			&msg.SyncedAt, &msg.ReadAt,
		)
		if err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}

	return messages, rows.Err()
}
