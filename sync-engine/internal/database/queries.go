package database

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"posduif/sync-engine/internal/models"
)

// User Queries

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

func (db *DB) GetUserByDeviceID(ctx context.Context, deviceID string) (*models.User, error) {
	var user models.User
	query := `SELECT id, username, user_type, device_id, online_status, last_seen,
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at
	          FROM users WHERE device_id = $1`

	err := db.Pool.QueryRow(ctx, query, deviceID).Scan(
		&user.ID, &user.Username, &user.UserType, &user.DeviceID,
		&user.OnlineStatus, &user.LastSeen, &user.EnrolledAt,
		&user.EnrollmentTokenID, &user.LastMessageSent, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (db *DB) GetUsers(ctx context.Context, filter models.UserFilter) ([]models.User, error) {
	query := `SELECT id, username, user_type, device_id, online_status, last_seen,
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at
	          FROM users WHERE 1=1`
	args := []interface{}{}
	argPos := 1

	if filter.ExcludeUserID != "" {
		query += fmt.Sprintf(" AND id != $%d", argPos)
		args = append(args, filter.ExcludeUserID)
		argPos++
	}

	if filter.Filter != "" {
		query += fmt.Sprintf(" AND username ILIKE $%d", argPos)
		args = append(args, "%"+filter.Filter+"%")
		argPos++
	}

	if filter.Status != nil {
		query += fmt.Sprintf(" AND online_status = $%d", argPos)
		args = append(args, *filter.Status)
		argPos++
	}

	query += " ORDER BY online_status DESC, username ASC"

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

func (db *DB) CreateUser(ctx context.Context, user *models.User) error {
	query := `INSERT INTO users (id, username, user_type, device_id, online_status, 
	          enrolled_at, enrollment_token_id, last_message_sent, created_at, updated_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`

	now := time.Now()
	if user.ID == "" {
		user.ID = uuid.New().String()
	}
	if user.CreatedAt.IsZero() {
		user.CreatedAt = now
	}
	user.UpdatedAt = now

	_, err := db.Pool.Exec(ctx, query,
		user.ID, user.Username, user.UserType, user.DeviceID,
		user.OnlineStatus, user.EnrolledAt, user.EnrollmentTokenID,
		user.LastMessageSent, user.CreatedAt, user.UpdatedAt,
	)
	return err
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

// Message Queries

func (db *DB) CreateMessage(ctx context.Context, msg *models.Message) error {
	query := `INSERT INTO messages (id, sender_id, recipient_id, content, status, 
	          created_at, updated_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7)`

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

	_, err := db.Pool.Exec(ctx, query,
		msg.ID, msg.SenderID, msg.RecipientID, msg.Content,
		msg.Status, msg.CreatedAt, msg.UpdatedAt,
	)
	return err
}

func (db *DB) GetMessages(ctx context.Context, filter models.MessageFilter) ([]models.Message, error) {
	query := `SELECT id, sender_id, recipient_id, content, status, created_at, 
	          updated_at, synced_at, read_at FROM messages WHERE 1=1`
	args := []interface{}{}
	argPos := 1

	if filter.RecipientID != nil {
		query += fmt.Sprintf(" AND recipient_id = $%d", argPos)
		args = append(args, *filter.RecipientID)
		argPos++
	}

	if filter.Status != nil {
		query += fmt.Sprintf(" AND status = $%d", argPos)
		args = append(args, *filter.Status)
		argPos++
	}

	query += " ORDER BY created_at DESC"

	if filter.Limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argPos)
		args = append(args, filter.Limit)
		argPos++
	}

	if filter.Offset > 0 {
		query += fmt.Sprintf(" OFFSET $%d", argPos)
		args = append(args, filter.Offset)
	}

	rows, err := db.Pool.Query(ctx, query, args...)
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

func (db *DB) GetUnreadCount(ctx context.Context, userID string) (int, error) {
	var count int
	query := `SELECT COUNT(*) FROM messages 
	          WHERE recipient_id = $1 AND status != 'read'`
	err := db.Pool.QueryRow(ctx, query, userID).Scan(&count)
	return count, err
}

func (db *DB) UpdateMessageStatus(ctx context.Context, messageID, status string) error {
	query := `UPDATE messages SET status = $1, updated_at = NOW()`

	if status == "synced" {
		query += ", synced_at = NOW()"
	} else if status == "read" {
		query += ", read_at = NOW()"
	}

	query += " WHERE id = $2"
	_, err := db.Pool.Exec(ctx, query, status, messageID)
	return err
}

// Enrollment Queries

func (db *DB) CreateEnrollmentToken(ctx context.Context, token *models.EnrollmentToken) error {
	query := `INSERT INTO enrollment_tokens (id, token, created_by, tenant_id, 
	          expires_at, created_at, updated_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7)`

	now := time.Now()
	if token.ID == "" {
		token.ID = uuid.New().String()
	}
	if token.Token == "" {
		token.Token = uuid.New().String()
	}
	if token.CreatedAt.IsZero() {
		token.CreatedAt = now
	}
	token.UpdatedAt = now

	_, err := db.Pool.Exec(ctx, query,
		token.ID, token.Token, token.CreatedBy, token.TenantID,
		token.ExpiresAt, token.CreatedAt, token.UpdatedAt,
	)
	return err
}

func (db *DB) GetEnrollmentToken(ctx context.Context, token string) (*models.EnrollmentToken, error) {
	var et models.EnrollmentToken
	query := `SELECT id, token, created_by, tenant_id, expires_at, used_at, 
	          device_id, created_at, updated_at
	          FROM enrollment_tokens WHERE token = $1`

	err := db.Pool.QueryRow(ctx, query, token).Scan(
		&et.ID, &et.Token, &et.CreatedBy, &et.TenantID,
		&et.ExpiresAt, &et.UsedAt, &et.DeviceID,
		&et.CreatedAt, &et.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &et, nil
}

func (db *DB) CompleteEnrollment(ctx context.Context, token, deviceID, username string) (string, error) {
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	// Update enrollment token
	updateQuery := `UPDATE enrollment_tokens 
	                SET used_at = NOW(), device_id = $1, updated_at = NOW()
	                WHERE token = $2 AND used_at IS NULL AND expires_at > NOW()`
	result, err := tx.Exec(ctx, updateQuery, deviceID, token)
	if err != nil {
		return "", err
	}
	if result.RowsAffected() == 0 {
		return "", fmt.Errorf("enrollment token not found or already used")
	}

	// Get token details
	var et models.EnrollmentToken
	getQuery := `SELECT id, created_by, tenant_id FROM enrollment_tokens WHERE token = $1`
	err = tx.QueryRow(ctx, getQuery, token).Scan(&et.ID, &et.CreatedBy, &et.TenantID)
	if err != nil {
		return "", err
	}

	// Check if user with this device_id already exists
	var userID string
	var existingUserID string
	checkQuery := `SELECT id FROM users WHERE device_id = $1`
	err = tx.QueryRow(ctx, checkQuery, deviceID).Scan(&existingUserID)
	
	now := time.Now()
	if err == nil {
		// User already exists - update enrollment info and username
		userID = existingUserID
		updateUserQuery := `UPDATE users 
		                   SET username = $1, enrolled_at = $2, enrollment_token_id = $3, updated_at = $4
		                   WHERE id = $5`
		_, err = tx.Exec(ctx, updateUserQuery, username, now, et.ID, now, userID)
		if err != nil {
			return "", fmt.Errorf("failed to update existing user: %w", err)
		}
	} else if errors.Is(err, pgx.ErrNoRows) {
		// User doesn't exist - create new one with provided username
		userID = uuid.New().String()
		// Use INSERT ... ON CONFLICT to handle username conflicts
		insertQuery := `INSERT INTO users (id, username, user_type, device_id, 
		                  enrolled_at, enrollment_token_id, created_at, updated_at)
		                  VALUES ($1, $2, 'mobile', $3, $4, $5, $6, $7)
		                  ON CONFLICT (username) DO UPDATE 
		                  SET device_id = EXCLUDED.device_id,
		                      enrolled_at = EXCLUDED.enrolled_at,
		                      enrollment_token_id = EXCLUDED.enrollment_token_id,
		                      updated_at = EXCLUDED.updated_at
		                  RETURNING id`
		err = tx.QueryRow(ctx, insertQuery,
			userID, username, deviceID, now, et.ID, now, now,
		).Scan(&userID)
		if err != nil {
			return "", fmt.Errorf("failed to create user: %w", err)
		}
	} else {
		// Unexpected error checking for user
		return "", fmt.Errorf("failed to check for existing user: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("failed to commit transaction: %w", err)
	}

	return userID, nil
}

// Sync Queries

func (db *DB) GetPendingMessagesForDevice(ctx context.Context, deviceID string, limit int) ([]models.Message, error) {
	query := `SELECT m.id, m.sender_id, m.recipient_id, m.content, m.status, 
	          m.created_at, m.updated_at, m.synced_at, m.read_at
	          FROM messages m
	          JOIN users u ON m.recipient_id = u.id
	          WHERE u.device_id = $1 AND m.status = 'pending_sync'
	          ORDER BY m.created_at ASC
	          LIMIT $2`

	rows, err := db.Pool.Query(ctx, query, deviceID, limit)
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

func (db *DB) GetSyncMetadata(ctx context.Context, deviceID string) (*models.SyncMetadata, error) {
	var sm models.SyncMetadata
	query := `SELECT id, device_id, last_sync_timestamp, last_synced_lsn, pending_outgoing_count, 
	          sync_status, created_at, updated_at
	          FROM sync_metadata WHERE device_id = $1`

	err := db.Pool.QueryRow(ctx, query, deviceID).Scan(
		&sm.ID, &sm.DeviceID, &sm.LastSyncTimestamp, &sm.LastSyncedLSN,
		&sm.PendingOutgoingCount, &sm.SyncStatus,
		&sm.CreatedAt, &sm.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &sm, nil
}

func (db *DB) UpdateSyncMetadata(ctx context.Context, sm *models.SyncMetadata) error {
	query := `INSERT INTO sync_metadata (device_id, last_sync_timestamp, last_synced_lsn,
	          pending_outgoing_count, sync_status, created_at, updated_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7)
	          ON CONFLICT (device_id) DO UPDATE SET
	          last_sync_timestamp = EXCLUDED.last_sync_timestamp,
	          last_synced_lsn = EXCLUDED.last_synced_lsn,
	          pending_outgoing_count = EXCLUDED.pending_outgoing_count,
	          sync_status = EXCLUDED.sync_status,
	          updated_at = NOW()`

	now := time.Now()
	if sm.CreatedAt.IsZero() {
		sm.CreatedAt = now
	}
	sm.UpdatedAt = now

	_, err := db.Pool.Exec(ctx, query,
		sm.DeviceID, sm.LastSyncTimestamp, sm.LastSyncedLSN, sm.PendingOutgoingCount,
		sm.SyncStatus, sm.CreatedAt, sm.UpdatedAt,
	)
	return err
}
