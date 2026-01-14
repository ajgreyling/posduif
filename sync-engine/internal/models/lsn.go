package models

import (
	"fmt"
	"strconv"
	"strings"
)

// LSN represents a PostgreSQL Log Sequence Number
type LSN uint64

// String returns the LSN in PostgreSQL format (e.g., "0/1234567")
func (l LSN) String() string {
	high := uint32(l >> 32)
	low := uint32(l)
	return fmt.Sprintf("%X/%08X", high, low)
}

// ParseLSN parses a PostgreSQL LSN string (e.g., "0/1234567") into an LSN
func ParseLSN(s string) (LSN, error) {
	parts := strings.Split(s, "/")
	if len(parts) != 2 {
		return 0, fmt.Errorf("invalid LSN format: %s", s)
	}

	high, err := strconv.ParseUint(parts[0], 16, 32)
	if err != nil {
		return 0, fmt.Errorf("invalid LSN high part: %w", err)
	}

	low, err := strconv.ParseUint(parts[1], 16, 32)
	if err != nil {
		return 0, fmt.Errorf("invalid LSN low part: %w", err)
	}

	return LSN((uint64(high) << 32) | uint64(low)), nil
}
