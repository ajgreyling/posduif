package sync

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"posduif/sync-engine/internal/config"
	"posduif/sync-engine/internal/database"
	"posduif/sync-engine/internal/models"
)

// WALService manages WAL reading in the background
type WALService struct {
	db            *database.DB
	changeTracker *ChangeTracker
	pool          *pgxpool.Pool
	slotManager   *database.ReplicationSlotManager
	cfg           *config.WALConfig
	slotName      string
	running       bool
	stopChan      chan struct{}
}

// NewWALService creates a new WAL service
func NewWALService(db *database.DB, changeTracker *ChangeTracker, pool *pgxpool.Pool, slotManager *database.ReplicationSlotManager, cfg *config.WALConfig) (*WALService, error) {
	slotName, err := slotManager.CreateReplicationSlot(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to create replication slot: %w", err)
	}

	return &WALService{
		db:            db,
		changeTracker: changeTracker,
		pool:          pool,
		slotManager:   slotManager,
		cfg:           cfg,
		slotName:      slotName,
		stopChan:      make(chan struct{}),
	}, nil
}

// Start starts the WAL reading service
func (ws *WALService) Start(ctx context.Context) error {
	if ws.running {
		return fmt.Errorf("WAL service already running")
	}

	ws.running = true

	// Run WAL reader in background
	go ws.runWALReader(ctx)

	return nil
}

// Stop stops the WAL reading service
func (ws *WALService) Stop() {
	if !ws.running {
		return
	}

	close(ws.stopChan)
	ws.running = false
}

// runWALReader runs the WAL reader loop
func (ws *WALService) runWALReader(ctx context.Context) {
	readInterval, err := time.ParseDuration(ws.cfg.ReadInterval)
	if err != nil {
		readInterval = time.Second
	}

	ticker := time.NewTicker(readInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ws.stopChan:
			return
		case <-ticker.C:
			if err := ws.readWALChanges(ctx); err != nil {
				log.Printf("Error reading WAL changes: %v", err)
			}
		}
	}
}

// readWALChanges reads WAL changes and adds them to the change tracker
func (ws *WALService) readWALChanges(ctx context.Context) error {
	// Get a connection from the pool for replication
	conn, err := ws.pool.Acquire(ctx)
	if err != nil {
		return fmt.Errorf("failed to acquire connection: %w", err)
	}
	defer conn.Release()

	// Create replication connection
	// Note: This is a simplified implementation
	// For production, you'd need a proper pgoutput parser
	// or use a library like pglogrepl
	
	// For now, we'll use a query-based approach to get recent changes
	// This is a fallback until full WAL parsing is implemented
	return ws.readChangesViaQuery(ctx)
}

// readChangesViaQuery reads changes using a query (fallback method)
// This is used until full WAL parsing is implemented
func (ws *WALService) readChangesViaQuery(ctx context.Context) error {
	// This is a placeholder - in production, you'd read from WAL
	// For now, we'll rely on the polling method as fallback
	// The WAL reader will be enhanced with proper pgoutput parsing
	
	// TODO: Implement proper WAL reading with pgoutput parser
	// For now, return nil to allow the system to work with polling fallback
	return nil
}

// GetStartLSN gets the starting LSN for replication
func (ws *WALService) GetStartLSN(ctx context.Context) (models.LSN, error) {
	// Get the confirmed flush LSN from the replication slot
	slotInfo, err := ws.slotManager.GetSlotInfo(ctx, ws.slotName)
	if err != nil {
		return 0, fmt.Errorf("failed to get slot info: %w", err)
	}

	confirmedFlushLSNStr, ok := slotInfo["confirmed_flush_lsn"].(string)
	if !ok || confirmedFlushLSNStr == "" {
		// No confirmed flush LSN, start from current WAL position
		var currentLSNStr string
		err := ws.pool.QueryRow(ctx, "SELECT pg_current_wal_lsn()").Scan(&currentLSNStr)
		if err != nil {
			return 0, fmt.Errorf("failed to get current WAL LSN: %w", err)
		}
		currentLSN, err := models.ParseLSN(currentLSNStr)
		if err != nil {
			return 0, fmt.Errorf("failed to parse current LSN: %w", err)
		}
		return currentLSN, nil
	}

	lsn, err := models.ParseLSN(confirmedFlushLSNStr)
	if err != nil {
		return 0, fmt.Errorf("failed to parse LSN: %w", err)
	}

	return lsn, nil
}
