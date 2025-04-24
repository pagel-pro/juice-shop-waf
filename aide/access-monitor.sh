#!/bin/bash
# Monitor ModSecurity logs for specific file access patterns with enhanced detection

LOG_FILE="/var/lib/aide/access-monitor.log"
# Check multiple possible log locations
POTENTIAL_LOG_PATHS=(
  "/host/var/log/modsecurity/access.log"
  "/host/var/log/modsecurity/modsec_audit.log"
  "/host/var/log/modsecurity/audit.log"
  "/host/var/log/nginx/access.log"
)
WATCH_PATTERNS=(
  "\.pdf"
  "\.jpg"
  "\.png"
  "\.db"
  "ftp/"
  "uploads/"
  "order_"
)

# Create log file
touch "$LOG_FILE"
echo "=== FILE ACCESS MONITOR STARTED $(date) ===" | tee -a "$LOG_FILE"
echo "Monitoring patterns: ${WATCH_PATTERNS[*]}" | tee -a "$LOG_FILE"

# Find actual log files
ACTIVE_LOG_FILES=()
echo "Searching for log files..." | tee -a "$LOG_FILE"
for log_path in "${POTENTIAL_LOG_PATHS[@]}"; do
  if [ -f "$log_path" ]; then
    echo "✅ Found log file: $log_path" | tee -a "$LOG_FILE"
    ACTIVE_LOG_FILES+=("$log_path")
  else
    echo "❌ Log file not found: $log_path" | tee -a "$LOG_FILE"
  fi
done

# If no logs found, check the directory structure
if [ ${#ACTIVE_LOG_FILES[@]} -eq 0 ]; then
  echo "⚠️ No log files found in expected locations. Listing available directories:" | tee -a "$LOG_FILE"
  ls -la /host/var/log/ | tee -a "$LOG_FILE"
  
  if [ -d "/host/var/log/modsecurity" ]; then
    echo "Directory exists, listing contents of /host/var/log/modsecurity:" | tee -a "$LOG_FILE"
    ls -la /host/var/log/modsecurity/ | tee -a "$LOG_FILE"
  fi

  # Auto-detect any log files as a fallback
  echo "🔍 Auto-detecting log files..." | tee -a "$LOG_FILE"
  AUTO_DETECTED_LOGS=$(find /host/var/log -name "*.log" -type f 2>/dev/null)
  if [ -n "$AUTO_DETECTED_LOGS" ]; then
    echo "Found log files:" | tee -a "$LOG_FILE"
    echo "$AUTO_DETECTED_LOGS" | tee -a "$LOG_FILE"
    # Add detected logs to active logs
    while read -r log_file; do
      ACTIVE_LOG_FILES+=("$log_file")
    done <<< "$AUTO_DETECTED_LOGS"
  else
    echo "No log files found with auto-detection" | tee -a "$LOG_FILE"
  fi
fi

# Function to check for file access in a log file
check_log_file() {
  local log_file=$1
  local matches
  
  if [ ! -f "$log_file" ]; then
    return 1
  fi
  
  # Create grep pattern from watch patterns
  local grep_pattern=$(IFS=\|; echo "${WATCH_PATTERNS[*]}")
  
  # Try to find matches in the log
  matches=$(tail -n 200 "$log_file" 2>/dev/null | grep -E "$grep_pattern" || true)
  
  # If matches found
  if [ -n "$matches" ]; then
    echo -e "\n🔍 FILE ACCESS DETECTED in $log_file at $(date):" | tee -a "$LOG_FILE"
    
    echo "$matches" | while read -r line; do
      # Extract key information based on log format
      # Try standard ModSecurity format first
      local timestamp=$(echo "$line" | grep -oE '\[[^]]+\]' | head -1 || echo "Unknown time")
      local url=$(echo "$line" | grep -oE '"[A-Z]+ [^"]+' | sed 's/"[A-Z]+ //' || echo "Unknown URL")
      local client=$(echo "$line" | awk '{print $1}' || echo "Unknown client")
      
      echo "⏱️ $timestamp" | tee -a "$LOG_FILE"
      echo "📄 File: $url" | tee -a "$LOG_FILE"
      echo "🖥️ Client: $client" | tee -a "$LOG_FILE"
      echo "-----------------------" | tee -a "$LOG_FILE"
    done
    return 0
  fi
  
  return 1
}

# Main monitoring loop
while true; do
  found_access=false
  
  # Check each active log file
  for log_file in "${ACTIVE_LOG_FILES[@]}"; do
    if check_log_file "$log_file"; then
      found_access=true
    fi
  done
  
  # If no events found but we should be detecting them, note that
  if [[ "$found_access" == "false" && -n "$AUTO_DETECTED_LOGS" ]]; then
    # Check if there are any known PDF accesses in our logs
    recent_modsec_logs=$(grep -l "pdf" /host/var/log/*/* 2>/dev/null || echo "")
    if [ -n "$recent_modsec_logs" ]; then
      echo "⚠️ PDF access detected in logs but not captured by monitor: $recent_modsec_logs" | tee -a "$LOG_FILE"
      cat $recent_modsec_logs | tail -n 10 | grep "pdf" | tee -a "$LOG_FILE"
    fi
  fi
  
  # Wait before next check
  sleep 5
done