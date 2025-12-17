#!/bin/bash

# Disk Space Cleanup Script
# This script identifies and optionally removes large files that are safe to delete
# (caches, downloads, temporary files, etc.)

set -euo pipefail
# Allow read to fail in non-interactive mode
set +e
read -t 0 < /dev/tty 2>/dev/null || export NON_INTERACTIVE=1
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default to dry-run mode
DRY_RUN=true
AUTO_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --execute)
            DRY_RUN=false
            shift
            ;;
        --yes)
            AUTO_CONFIRM=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--execute] [--yes]"
            echo "  --execute: Actually delete files (default is dry-run)"
            echo "  --yes: Auto-confirm deletions (use with --execute)"
            exit 1
            ;;
    esac
done

# Function to calculate size before deletion
calculate_size() {
    local path="$1"
    if [ -e "$path" ]; then
        du -sh "$path" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# Function to delete directory/file
safe_delete() {
    local path="$1"
    local description="$2"
    local size=$(calculate_size "$path")
    
    if [ ! -e "$path" ]; then
        echo -e "${YELLOW}⚠  $description: Not found${NC}"
        return
    fi
    
    if [ "$size" = "0" ] || [ -z "$size" ]; then
        echo -e "${YELLOW}⚠  $description: Empty or inaccessible${NC}"
        return
    fi
    
    echo -e "${BLUE}📦 $description: ${GREEN}$size${NC}"
    
    if [ "$DRY_RUN" = false ]; then
        if [ "$AUTO_CONFIRM" = false ] && [ "${NON_INTERACTIVE:-0}" = "0" ]; then
            read -p "Delete? (y/N): " -n 1 -r < /dev/tty 2>/dev/null || {
                echo -e "${YELLOW}Non-interactive mode detected. Skipping...${NC}"
                echo -e "${YELLOW}Use --yes to auto-confirm deletions${NC}"
                return
            }
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Skipped${NC}"
                return
            fi
        elif [ "$AUTO_CONFIRM" = false ]; then
            echo -e "${YELLOW}Non-interactive mode. Skipping (use --yes to auto-confirm)${NC}"
            return
        fi
        
        rm -rf "$path"
        echo -e "${GREEN}✓ Deleted${NC}"
    else
        echo -e "${YELLOW}[DRY RUN] Would delete${NC}"
    fi
}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           Disk Space Cleanup Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}⚠  DRY RUN MODE - No files will be deleted${NC}"
    echo -e "${YELLOW}   Run with --execute to actually delete files${NC}"
else
    echo -e "${RED}⚠  EXECUTE MODE - Files will be permanently deleted!${NC}"
fi
echo ""

# Show current disk usage
echo -e "${BLUE}Current disk usage:${NC}"
df -h / | tail -1 | awk '{print "  Used: " $3 " / " $2 " (" $5 " used)"}'
echo ""

# Show what will be cleaned
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Items to clean:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

TOTAL_SIZE=0

# 1. Homebrew download cache (8.5GB)
echo -e "${BLUE}[1] Homebrew Download Cache${NC}"
safe_delete "$HOME/Library/Caches/Homebrew/downloads" "Homebrew downloads cache"
echo ""

# 2. Hugging Face cache (9.3GB)
echo -e "${BLUE}[2] Hugging Face Model Cache${NC}"
safe_delete "$HOME/.cache/huggingface" "Hugging Face cache"
echo ""

# 3. Microsoft Edge cache (2.2GB)
echo -e "${BLUE}[3] Microsoft Edge Cache${NC}"
safe_delete "$HOME/Library/Caches/Microsoft Edge" "Microsoft Edge cache"
echo ""

# 4. Google Chrome/Android Studio cache (821MB)
echo -e "${BLUE}[4] Google Application Caches${NC}"
safe_delete "$HOME/Library/Caches/Google" "Google caches"
echo ""

# 5. pip cache (775MB)
echo -e "${BLUE}[5] Python pip Cache${NC}"
safe_delete "$HOME/Library/Caches/pip" "pip cache"
echo ""

# 6. JetBrains cache (377MB)
echo -e "${BLUE}[6] JetBrains IDE Cache${NC}"
safe_delete "$HOME/Library/Caches/JetBrains" "JetBrains cache"
echo ""

# 7. Yarn cache (182MB)
echo -e "${BLUE}[7] Yarn Package Cache${NC}"
safe_delete "$HOME/Library/Caches/Yarn" "Yarn cache"
echo ""


# 9. Downloads folder - Large files only
echo -e "${BLUE}[9] Large Files in Downloads${NC}"
if [ -d "$HOME/Downloads" ]; then
    echo "  Large files (>100MB) in Downloads:"
    find "$HOME/Downloads" -type f -size +100M 2>/dev/null | while read -r file; do
        size=$(du -h "$file" 2>/dev/null | awk '{print $1}')
        echo -e "    ${BLUE}📄 $(basename "$file"): ${GREEN}$size${NC}"
        if [ "$DRY_RUN" = false ]; then
            if [ "$AUTO_CONFIRM" = false ] && [ "${NON_INTERACTIVE:-0}" = "0" ]; then
                read -p "      Delete? (y/N): " -n 1 -r < /dev/tty 2>/dev/null || {
                    echo -e "      ${YELLOW}Skipped (non-interactive)${NC}"
                    continue
                }
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -f "$file"
                    echo -e "      ${GREEN}✓ Deleted${NC}"
                fi
            elif [ "$AUTO_CONFIRM" = true ]; then
                rm -f "$file"
                echo -e "      ${GREEN}✓ Deleted${NC}"
            else
                echo -e "      ${YELLOW}Skipped (non-interactive, use --yes to auto-confirm)${NC}"
            fi
        fi
    done
fi
echo ""

# 10. VirtualBox VMs (6.4GB) - Ask separately as this is more destructive
echo -e "${BLUE}[10] VirtualBox Virtual Machines${NC}"
if [ -d "$HOME/VirtualBox VMs" ]; then
    size=$(calculate_size "$HOME/VirtualBox VMs")
    echo -e "${RED}⚠  WARNING: VirtualBox VMs directory: ${GREEN}$size${NC}"
    echo -e "${YELLOW}   This contains virtual machine disk images.${NC}"
    echo -e "${YELLOW}   Only delete if you're sure you don't need these VMs!${NC}"
    if [ "$DRY_RUN" = false ]; then
        if [ "$AUTO_CONFIRM" = false ]; then
            read -p "Delete VirtualBox VMs? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$HOME/VirtualBox VMs"
                echo -e "${GREEN}✓ Deleted${NC}"
            else
                echo -e "${YELLOW}Skipped${NC}"
            fi
        else
            rm -rf "$HOME/VirtualBox VMs"
            echo -e "${GREEN}✓ Deleted${NC}"
        fi
    else
        echo -e "${YELLOW}[DRY RUN] Would delete${NC}"
    fi
fi
echo ""

# 11. Vagrant boxes (2.7GB)
echo -e "${BLUE}[11] Vagrant Boxes${NC}"
if [ -d "$HOME/.vagrant.d/boxes" ]; then
    size=$(calculate_size "$HOME/.vagrant.d/boxes")
    echo -e "${YELLOW}⚠  Vagrant boxes: ${GREEN}$size${NC}"
    echo -e "${YELLOW}   These can be re-downloaded with 'vagrant box add'${NC}"
    if [ "$DRY_RUN" = false ]; then
        if [ "$AUTO_CONFIRM" = false ]; then
            read -p "Delete Vagrant boxes? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$HOME/.vagrant.d/boxes"
                echo -e "${GREEN}✓ Deleted${NC}"
            else
                echo -e "${YELLOW}Skipped${NC}"
            fi
        else
            rm -rf "$HOME/.vagrant.d/boxes"
            echo -e "${GREEN}✓ Deleted${NC}"
        fi
    else
        echo -e "${YELLOW}[DRY RUN] Would delete${NC}"
    fi
fi
echo ""

# 12. Node.js cache
echo -e "${BLUE}[12] Node.js Cache${NC}"
safe_delete "$HOME/.cache/node" "Node.js cache"
echo ""

# 13. Prisma cache
echo -e "${BLUE}[13] Prisma Cache${NC}"
safe_delete "$HOME/.cache/prisma" "Prisma cache"
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}Dry run complete!${NC}"
    echo -e "${YELLOW}Run with --execute to actually delete files${NC}"
else
    echo -e "${GREEN}Cleanup complete!${NC}"
fi
echo ""
echo -e "${BLUE}Final disk usage:${NC}"
df -h / | tail -1 | awk '{print "  Used: " $3 " / " $2 " (" $5 " used)"}'
echo ""
