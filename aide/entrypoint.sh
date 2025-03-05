#!/bin/bash
set -e

# Initialize the database if it doesn't exist
if [ ! -f /var/lib/aide/aide.db ]; then
  echo "Initializing AIDE database"
  aide --init --config=/etc/aide/aide.conf || true
  cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db || true
fi

# Function to send alerts
send_alert() {
  local changes=$1
  echo "ALERT: AIDE detected changes at $(date)" > /tmp/aide_alert
  echo "=======================================" >> /tmp/aide_alert
  echo "$changes" >> /tmp/aide_alert
  
  # Log to container logs (visible with docker logs)
  cat /tmp/aide_alert >&2
  
  # If you want email alerts, configure this part
  # mail -s "AIDE Intrusion Alert" admin@example.com < /tmp/aide_alert
}

# Run AIDE check periodically and don't fail on differences
while true; do
  echo "Running AIDE check at $(date)"
  
  # Capture AIDE output to detect changes
  AIDE_OUTPUT=$(aide --check --config=/etc/aide/aide.conf 2>&1) || true
  
  # Check if AIDE found changes
  if echo "$AIDE_OUTPUT" | grep -q "found differences"; then
    send_alert "$AIDE_OUTPUT"
  fi
  
  # Sleep for 60 seconds before next check
  sleep 60  # Check every minute while testing, increase later
done