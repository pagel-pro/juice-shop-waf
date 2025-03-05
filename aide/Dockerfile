FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y aide curl mailutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create directory structure for mounted volumes
RUN mkdir -p /host/var/log/modsecurity /host/etc/modsecurity /host/juice-shop-data

RUN mkdir -p /host/etc/nginx/conf.d \
    /host/var/log/modsecurity \
    /host/etc/modsecurity \
    /host/juice-shop-data

COPY aide.conf /etc/aide/aide.conf
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]