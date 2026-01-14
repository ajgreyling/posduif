package database

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"posduif/sync-engine/internal/config"
)

// ReplicationSlotManager manages PostgreSQL logical replication slots
type ReplicationSlotManager struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

// NewReplicationSlotManager creates a new replication slot manager
func NewReplicationSlotManager(pool *pgxpool.Pool, cfg *config.Config) *ReplicationSlotManager {
	return &ReplicationSlotManager{
		pool: pool,
		cfg:  cfg,
	}
}

// GetSlotName returns the replication slot name for the current tenant
func (r *ReplicationSlotManager) GetSlotName() string {
	// Use tenant-specific slot name based on database name
	// For database-per-tenant, use the database name as part of slot name
	dbName := r.cfg.Postgres.DB
	// Sanitize database name for use in slot name (PostgreSQL slot names have restrictions)
	slotName := fmt.Sprintf("posduif_sync_%s", strings.ReplaceAll(dbName, "-", "_"))
	// PostgreSQL slot names are limited to 63 characters
	if len(slotName) > 63 {
		slotName = slotName[:63]
	}
	return slotName
}

// CreateReplicationSlot creates a logical replication slot if it doesn't exist
func (r *ReplicationSlotManager) CreateReplicationSlot(ctx context.Context) (string, error) {
	slotName := r.GetSlotName()

	// Check if slot already exists
	exists, err := r.SlotExists(ctx, slotName)
	if err != nil {
		return "", fmt.Errorf("failed to check if slot exists: %w", err)
	}

	if exists {
		return slotName, nil // Slot already exists
	}

	// Create the replication slot using pgoutput plugin
	// PostgreSQL 18 returns a record type, so we need to expand it into separate columns
	createQuery := `SELECT slot_name, lsn FROM pg_create_logical_replication_slot($1, 'pgoutput')`
	var slotNameResult string
	var lsnStr string
	err = r.pool.QueryRow(ctx, createQuery, slotName).Scan(&slotNameResult, &lsnStr)
	if err != nil {
		return "", fmt.Errorf("failed to create replication slot: %w", err)
	}

	return slotNameResult, nil
}

// SlotExists checks if a replication slot exists
func (r *ReplicationSlotManager) SlotExists(ctx context.Context, slotName string) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 
			FROM pg_replication_slots 
			WHERE slot_name = $1
		)
	`
	var exists bool
	err := r.pool.QueryRow(ctx, query, slotName).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check slot existence: %w", err)
	}
	return exists, nil
}

// DropReplicationSlot drops a replication slot (use with caution)
func (r *ReplicationSlotManager) DropReplicationSlot(ctx context.Context, slotName string) error {
	query := `SELECT pg_drop_replication_slot($1)`
	_, err := r.pool.Exec(ctx, query, slotName)
	if err != nil {
		return fmt.Errorf("failed to drop replication slot: %w", err)
	}
	return nil
}

// GetSlotInfo returns information about a replication slot
func (r *ReplicationSlotManager) GetSlotInfo(ctx context.Context, slotName string) (map[string]interface{}, error) {
	query := `
		SELECT 
			slot_name,
			plugin,
			slot_type,
			active,
			restart_lsn,
			confirmed_flush_lsn
		FROM pg_replication_slots
		WHERE slot_name = $1
	`
	var info struct {
		SlotName          string
		Plugin            string
		SlotType          string
		Active            bool
		RestartLSN        *string
		ConfirmedFlushLSN *string
	}
	err := r.pool.QueryRow(ctx, query, slotName).Scan(
		&info.SlotName,
		&info.Plugin,
		&info.SlotType,
		&info.Active,
		&info.RestartLSN,
		&info.ConfirmedFlushLSN,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get slot info: %w", err)
	}

	result := map[string]interface{}{
		"slot_name":          info.SlotName,
		"plugin":             info.Plugin,
		"slot_type":          info.SlotType,
		"active":             info.Active,
		"restart_lsn":        "",
		"confirmed_flush_lsn": "",
	}
	if info.RestartLSN != nil {
		result["restart_lsn"] = *info.RestartLSN
	}
	if info.ConfirmedFlushLSN != nil {
		result["confirmed_flush_lsn"] = *info.ConfirmedFlushLSN
	}
	return result, nil
}
