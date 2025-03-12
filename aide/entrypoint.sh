#!/bin/bash
set -e

# Start file access monitoring script
if [ -f /access-monitor.sh ]; then
  echo "🔍 Starting access monitor for PDF and sensitive files..."
  /access-monitor.sh &
  echo "✅ Access monitor started in background"
fi

# Start file change monitoring script
if [ -f /file-monitor.sh ]; then
  echo "🔍 Starting file integrity monitor..."
  /file-monitor.sh &
  echo "✅ File integrity monitor started in background"
fi


# Initialize the database if it doesn't exist
if [ ! -f /var/lib/aide/aide.db ] || [ ! -s /var/lib/aide/aide.db ]; then
  echo "Initializing AIDE database"
  # Make sure the directory exists
  mkdir -p /var/lib/aide
  
  # Try to initialize AIDE database with additional debug
  echo "Running AIDE initialization..."
  AIDE_INIT_OUTPUT=$(aide --init --config=/etc/aide/aide.conf 2>&1) || true
  echo "$AIDE_INIT_OUTPUT"
  
  # Check if database was created
  if [ -f /var/lib/aide/aide.db.new ]; then
    echo "Database initialization successful, copying to aide.db"
    cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    
    # Create initial backups of monitored files for future diff comparisons
    echo "Creating initial backups of monitored files..."
    # Create backup directory
    mkdir -p /var/lib/aide/backups
    
    # Find monitored files from aide.conf excluding commented lines and special patterns
    MONITORED_PATHS=$(grep -v "^#" /etc/aide/aide.conf | grep -v "^!" | grep -E "^/.*" | awk '{print $1}')
    
    # Backup each monitored path
    for path in $MONITORED_PATHS; do
      if [ -d "$path" ]; then
        echo "Creating backups for directory: $path"
        find "$path" -type f -exec sh -c 'mkdir -p "/var/lib/aide/backups/$(dirname "{}")" && cp -a "{}" "/var/lib/aide/backups/{}"' \; 2>/dev/null || true
      elif [ -f "$path" ]; then
        echo "Creating backup for file: $path"
        # Create directory structure
        mkdir -p "/var/lib/aide/backups/$(dirname "$path")"
        cp -a "$path" "/var/lib/aide/backups/$path" 2>/dev/null || true
      fi
    done
    echo "Initial backups created"
  else
    echo "Database initialization failed. Creating empty database."
    touch /var/lib/aide/aide.db
  fi
fi

# Function to get file metadata
get_file_metadata() {
  local file=$1
  local output=""
  
  if [ -f "$file" ]; then
    local size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null)
    local perms=$(stat -c %A "$file" 2>/dev/null || stat -f %Mp%Lp "$file" 2>/dev/null)
    local owner=$(stat -c %U "$file" 2>/dev/null || stat -f %Su "$file" 2>/dev/null)
    local group=$(stat -c %G "$file" 2>/dev/null || stat -f %Sg "$file" 2>/dev/null)
    local modified=$(stat -c %y "$file" 2>/dev/null || stat -f %Sm "$file" 2>/dev/null)
    
    output="Size: $size bytes | Permissions: $perms | Owner: $owner:$group | Modified: $modified"
  fi
  
  echo "$output"
}

# Function to send alerts
send_alert() {
  local changes=$1
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local changed_files=$(echo "$changes" | grep -E "^File: " | wc -l)
  local changed_dirs=$(echo "$changes" | grep -E "^Directory: " | wc -l)
  
  echo -e "\n\n╔══════════════════════════════════════════════════════════╗"
  echo -e "║ 🚨 AIDE DETECTED CHANGES AT $timestamp 🚨 ║"
  echo -e "╚══════════════════════════════════════════════════════════╝"
  
  # Add statistics section
  echo -e "\n📈 STATISTICS:"
  echo -e "📁 Directories changed: $changed_dirs"
  echo -e "📄 Files changed: $changed_files"
  
  # First, add a summary section showing what was changed
  echo -e "\n📊 SUMMARY OF CHANGES DETECTED:"
  echo "$changes" | grep -A 2 "^Summary:" 
  
  # Extract both File: and Directory: entries from AIDE output
  echo -e "\n📋 DETAILED CHANGES:"
  
  # Add the AIDE detailed output for each file
  echo "$changes" | grep -A 20 "^Directory: \|^File: " | grep -v "^--$"
  
  echo -e "\n📄 CONTENT CHANGES WITH DIFFS:"
  
  # Extract changed file paths from AIDE output (both directories and files)
  echo "$changes" | grep -E "^File: " | awk '{print $2}' > /tmp/changed_files
  
  # Track how many files we've processed
  local processed=0
  
  # For each changed file, show a diff and create a new backup
  while read -r file; do
    # Determine backup path
    backup_path="/var/lib/aide/backups$file"
    processed=$((processed + 1))
    
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📝 FILE $processed/$changed_files: $file"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show file metadata
    metadata=$(get_file_metadata "$file")
    if [ -n "$metadata" ]; then
      echo -e "ℹ️ METADATA: $metadata"
    fi
    
    if [ -f "$file" ] && [ -f "$backup_path" ]; then
      echo -e "\n🔄 CHANGES DETECTED (- old, + new):"
      
      # Use diff with color if available
      if command -v colordiff >/dev/null 2>&1; then
        colordiff -u "$backup_path" "$file" || true
      else
        diff -u "$backup_path" "$file" || true
      fi
      
      # Create directory structure for backup if it doesn't exist
      mkdir -p "$(dirname "$backup_path")"
      
      # Update backup with new version
      cp -f "$file" "$backup_path"
      echo -e "\n✅ Backup updated: $backup_path"
      
      # If it's a text file, count lines and words
      if file "$file" | grep -q text; then
        wc_output=$(wc "$file")
        echo -e "📊 File statistics: $wc_output"
      fi
    elif [ -f "$file" ]; then
      echo -e "\n🆕 NEW FILE CREATED:"
      
      # If it's a text file, show content
      if file "$file" | grep -q text; then
        echo -e "\n--- FILE CONTENT BEGIN ---"
        cat "$file"
        echo -e "--- FILE CONTENT END ---\n"
      else
        echo -e "[Binary file - content not shown]"
      fi
      
      # Create directory structure for backup
      mkdir -p "$(dirname "$backup_path")"
      
      # Create backup of new file
      cp -f "$file" "$backup_path"
      echo -e "\n✅ Backup created: $backup_path"
    else
      echo -e "\n❌ FILE DELETED:"
      if [ -f "$backup_path" ]; then
        echo -e "Previous content was:"
        
        # If it's a text file, show content
        if file "$backup_path" | grep -q text; then
          echo -e "\n--- DELETED CONTENT BEGIN ---"
          cat "$backup_path"
          echo -e "--- DELETED CONTENT END ---\n"
        else
          echo -e "[Binary file - content not shown]"
        fi
        
        rm -f "$backup_path"
        echo -e "\n✅ Backup removed"
      fi
    fi
  done < /tmp/changed_files
  
  echo -e "\n✅ Finished processing $processed files."
  echo -e "⏱️ Alert generated at: $(date +"%Y-%m-%d %H:%M:%S")"
  
  # Save the changes to a timestamped file for later reference
  local report_file="/var/lib/aide/reports/changes_${timestamp//[: ]/_}.log"
  mkdir -p /var/lib/aide/reports
  echo "$changes" > "$report_file"
  echo -e "📋 Full report saved to: $report_file"
}

# Create reports directory
mkdir -p /var/lib/aide/reports

# Print startup message
echo "🔒 AIDE Integrity Monitoring Started at $(date)"
echo "🔍 Monitoring files according to /etc/aide/aide.conf"
echo "⏱️ Check interval: 60 seconds"

# Run AIDE check periodically and don't fail on differences
while true; do
  echo "⏱️ Running AIDE check at $(date)"
  
  # Capture AIDE output to detect changes
  AIDE_OUTPUT=$(aide --check --config=/etc/aide/aide.conf 2>&1) || true
  
  # Check if AIDE found changes
  if echo "$AIDE_OUTPUT" | grep -q "found differences"; then
    send_alert "$AIDE_OUTPUT"
  else
    echo "✅ No changes detected at $(date)"
  fi
  
  # Sleep for 60 seconds before next check
  sleep 5  # Check every minute while testing, increase later
done