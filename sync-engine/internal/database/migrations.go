package database

import (
	"context"
	"fmt"
)

// RunMigrations runs all database migrations
func (db *DB) RunMigrations(ctx context.Context) error {
	// Migration 1: Add last_synced_lsn column to sync_metadata
	if err := db.migrationAddLSNColumn(ctx); err != nil {
		return fmt.Errorf("migration 1 failed: %w", err)
	}

	// Migration 2: Create index on last_synced_lsn
	if err := db.migrationCreateLSNIndex(ctx); err != nil {
		return fmt.Errorf("migration 2 failed: %w", err)
	}

	return nil
}

// migrationAddLSNColumn adds the last_synced_lsn column to sync_metadata table
func (db *DB) migrationAddLSNColumn(ctx context.Context) error {
	// Check if column already exists
	var exists bool
	checkQuery := `
		SELECT EXISTS (
			SELECT 1 
			FROM information_schema.columns 
			WHERE table_name = 'sync_metadata' 
			AND column_name = 'last_synced_lsn'
		)
	`
	err := db.Pool.QueryRow(ctx, checkQuery).Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if column exists: %w", err)
	}

	if exists {
		return nil // Column already exists, skip migration
	}

	// Add the column
	alterQuery := `ALTER TABLE sync_metadata ADD COLUMN last_synced_lsn pg_lsn`
	_, err = db.Pool.Exec(ctx, alterQuery)
	if err != nil {
		return fmt.Errorf("failed to add last_synced_lsn column: %w", err)
	}

	return nil
}

// migrationCreateLSNIndex creates an index on last_synced_lsn
func (db *DB) migrationCreateLSNIndex(ctx context.Context) error {
	// Check if index already exists
	var exists bool
	checkQuery := `
		SELECT EXISTS (
			SELECT 1 
			FROM pg_indexes 
			WHERE tablename = 'sync_metadata' 
			AND indexname = 'idx_sync_metadata_lsn'
		)
	`
	err := db.Pool.QueryRow(ctx, checkQuery).Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if index exists: %w", err)
	}

	if exists {
		return nil // Index already exists, skip migration
	}

	// Create the index
	createIndexQuery := `
		CREATE INDEX idx_sync_metadata_lsn 
		ON sync_metadata(last_synced_lsn) 
		WHERE last_synced_lsn IS NOT NULL
	`
	_, err = db.Pool.Exec(ctx, createIndexQuery)
	if err != nil {
		return fmt.Errorf("failed to create LSN index: %w", err)
	}

	return nil
}
