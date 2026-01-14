package models

import (
	"time"
)

type Message struct {
	ID          string     `json:"id" db:"id"`
	SenderID    string     `json:"sender_id" db:"sender_id"`
	RecipientID string     `json:"recipient_id" db:"recipient_id"`
	Content     string     `json:"content" db:"content"`
	Status      string     `json:"status" db:"status"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
	SyncedAt    *time.Time `json:"synced_at,omitempty" db:"synced_at"`
	ReadAt      *time.Time `json:"read_at,omitempty" db:"read_at"`
}

type CreateMessageRequest struct {
	RecipientID string `json:"recipient_id"`
	Content     string `json:"content"`
}
