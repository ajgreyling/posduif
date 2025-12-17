package redis

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"posduif/sync-engine/internal/config"
)

type Publisher struct {
	client *redis.Client
	config *config.Config
}

func NewPublisher(client *redis.Client, cfg *config.Config) *Publisher {
	return &Publisher{
		client: client,
		config: cfg,
	}
}

func (p *Publisher) PublishMessageEvent(ctx context.Context, eventType string, data map[string]interface{}) error {
	if !p.config.Redis.Streams.Enabled {
		return nil
	}

	event := map[string]interface{}{
		"type":      eventType,
		"timestamp": time.Now().Unix(),
		"data":      data,
	}

	eventJSON, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}

	streamName := fmt.Sprintf("events:%s", eventType)
	_, err = p.client.XAdd(ctx, &redis.XAddArgs{
		Stream: streamName,
		MaxLen: int64(p.config.Redis.Streams.MaxLength),
		Values: map[string]interface{}{
			"event": string(eventJSON),
		},
	}).Result()

	return err
}

func (p *Publisher) PublishNewMessage(ctx context.Context, messageID, recipientID string, unreadCount int) error {
	data := map[string]interface{}{
		"message_id":   messageID,
		"recipient_id": recipientID,
		"unread_count": unreadCount,
		"timestamp":    time.Now().Unix(),
	}
	return p.PublishMessageEvent(ctx, "new_message", data)
}

func (p *Publisher) PublishMessageRead(ctx context.Context, messageID string) error {
	data := map[string]interface{}{
		"message_id": messageID,
		"timestamp":  time.Now().Unix(),
	}
	return p.PublishMessageEvent(ctx, "message_read", data)
}

