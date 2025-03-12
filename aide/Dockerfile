FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y aide curl mailutils file diffutils grep sed inotify-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create directory structure
RUN mkdir -p /host/var/log/modsecurity /host/etc/modsecurity /host/juice-shop-data \
    /host/etc/nginx/conf.d \
    /host/etc/modsecurity.d \
    /var/lib/aide/file-backups

COPY aide.conf /etc/aide/aide.conf
COPY entrypoint.sh /entrypoint.sh
COPY file-monitor.sh /file-monitor.sh
COPY access-monitor.sh /access-monitor.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /file-monitor.sh /access-monitor.sh

# Pre-initialize the AIDE database
RUN mkdir -p /var/lib/aide && \
    touch /var/lib/aide/aide.db

ENTRYPOINT ["/entrypoint.sh"]