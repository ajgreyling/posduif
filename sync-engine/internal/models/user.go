package models

import (
	"time"
)

type User struct {
	ID                string     `json:"id" db:"id"`
	Username          string     `json:"username" db:"username"`
	UserType          string     `json:"user_type" db:"user_type"`
	DeviceID          *string    `json:"device_id,omitempty" db:"device_id"`
	OnlineStatus      bool       `json:"online_status" db:"online_status"`
	LastSeen          *time.Time `json:"last_seen,omitempty" db:"last_seen"`
	EnrolledAt        *time.Time `json:"enrolled_at,omitempty" db:"enrolled_at"`
	EnrollmentTokenID *string    `json:"enrollment_token_id,omitempty" db:"enrollment_token_id"`
	LastMessageSent   *string    `json:"last_message_sent,omitempty" db:"last_message_sent"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at" db:"updated_at"`
}

type UserFilter struct {
	Filter       string
	Status       *bool
	ExcludeUserID string
}


