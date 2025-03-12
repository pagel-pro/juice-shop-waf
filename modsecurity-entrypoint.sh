#!/bin/bash
set -e

# Ensure log directory exists and has proper permissions
mkdir -p /var/log/modsecurity
chmod -R 755 /var/log/modsecurity
touch /var/log/modsecurity/access.log /var/log/modsecurity/error.log /var/log/modsecurity/audit.log
chmod 666 /var/log/modsecurity/*.log

# Pass control to the original entrypoint
exec /docker-entrypoint.sh "$@"