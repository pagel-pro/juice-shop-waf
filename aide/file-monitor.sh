#!/bin/bash
# Real-time file change monitoring for Juice Shop and ModSecurity

# Configuration
WATCH_DIRS=(
  "/host/juice-shop-data"
  "/host/var/log/modsecurity"
  "/host/etc/modsecurity"
  "/host/etc/modsecurity.d"
  "/host/etc/nginx"
)
LOG_FILE="/var/lib/aide/file-monitor.log"
BACKUP_DIR="/var/lib/aide/file-backups"
CHECK_INTERVAL="${CHECK_INTERVAL:-10}"

# Create directories
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"

echo "=== FILE CHANGE MONITOR STARTED $(date) ===" | tee -a "$LOG_FILE"
echo "Monitoring directories:" | tee -a "$LOG_FILE"
for dir in "${WATCH_DIRS[@]}"; do
  echo "- $dir" | tee -a "$LOG_FILE"
done

# Initial file list
find "${WATCH_DIRS[@]}" -type f 2>/dev/null | sort > /tmp/files.baseline

# Main monitoring loop
while true; do
  # Get current file list
  find "${WATCH_DIRS[@]}" -type f 2>/dev/null | sort > /tmp/files.current
  
  # Find new files
  NEW_FILES=$(comm -13 /tmp/files.baseline /tmp/files.current)
  
  # Find deleted files
  DELETED_FILES=$(comm -23 /tmp/files.baseline /tmp/files.current)
  
  # Find modified files (excluding new/deleted)
  MODIFIED_FILES=""
  while read -r file; do
    if grep -q "$file" /tmp/files.baseline && grep -q "$file" /tmp/files.current; then
      # File exists in both lists, check if modified
      if [[ -f "$file" ]]; then
        OLD_HASH=$(grep -A1 "$file" /tmp/files.hashes 2>/dev/null | tail -1) || OLD_HASH=""
        NEW_HASH=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1) || NEW_HASH=""
        
        if [[ "$OLD_HASH" != "$NEW_HASH" ]]; then
          MODIFIED_FILES="$MODIFIED_FILES\n$file"
        fi
      fi
    fi
  done < /tmp/files.current
  
  # Log changes if any detected
  if [[ -n "$NEW_FILES" || -n "$DELETED_FILES" || -n "$MODIFIED_FILES" ]]; then
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n=== CHANGES DETECTED AT $TIMESTAMP ===" | tee -a "$LOG_FILE"
    
    # Process new files
    if [[ -n "$NEW_FILES" ]]; then
      echo -e "\n🆕 NEW FILES:" | tee -a "$LOG_FILE"
      echo "$NEW_FILES" | while read -r file; do
        if [[ -f "$file" ]]; then
          TYPE=$(file -b "$file") 
          SIZE=$(stat -c %s "$file" 2>/dev/null || echo "unknown")
          echo "  • $file ($SIZE bytes, $TYPE)" | tee -a "$LOG_FILE"
          
          # Backup new file
          REL_PATH="${file#/host/}"
          mkdir -p "$BACKUP_DIR/$(dirname "$REL_PATH")"
          cp "$file" "$BACKUP_DIR/$REL_PATH" 2>/dev/null
        fi
      done
    fi
    
    # Process deleted files
    if [[ -n "$DELETED_FILES" ]]; then
      echo -e "\n❌ DELETED FILES:" | tee -a "$LOG_FILE"
      echo "$DELETED_FILES" | while read -r file; do
        echo "  • $file" | tee -a "$LOG_FILE"
      done
    fi
    
    # Process modified files
    if [[ -n "$MODIFIED_FILES" ]]; then
      echo -e "\n📝 MODIFIED FILES:" | tee -a "$LOG_FILE"
      echo -e "$MODIFIED_FILES" | while read -r file; do
        if [[ -f "$file" ]]; then
          MTIME=$(stat -c %y "$file" 2>/dev/null || echo "unknown")
          echo "  • $file (Modified: $MTIME)" | tee -a "$LOG_FILE"
          
          # Show differences for text files
          if file "$file" | grep -q text; then
            REL_PATH="${file#/host/}"
            if [[ -f "$BACKUP_DIR/$REL_PATH" ]]; then
              echo "    --- DIFFERENCES ---" | tee -a "$LOG_FILE"
              diff -u "$BACKUP_DIR/$REL_PATH" "$file" | head -20 | tee -a "$LOG_FILE"
            fi
            
            # Update backup
            mkdir -p "$BACKUP_DIR/$(dirname "$REL_PATH")"
            cp "$file" "$BACKUP_DIR/$REL_PATH" 2>/dev/null
          fi
        fi
      done
    fi
  fi
  
  # Update file baseline and create hash database for future comparisons
  cp /tmp/files.current /tmp/files.baseline
  find "${WATCH_DIRS[@]}" -type f -exec sha256sum {} \; > /tmp/files.hashes 2>/dev/null
  
  sleep $CHECK_INTERVAL
done