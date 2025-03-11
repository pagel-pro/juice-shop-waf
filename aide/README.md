# Forensic Readyness with IDS For Demonstration

A security-enhanced setup of OWASP Juice Shop with ModSecurity WAF and AIDE intrusion detection monitoring.

## Overview
This project provides a containerized security lab with three main components:

1. OWASP Juice Shop: A deliberately vulnerable web application for security training
2. ModSecurity WAF: A web application firewall that protects (or monitors) the 3. Juice Shop application
AIDE IDS: An intrusion detection system that monitors file integrity changes

## Architecture
The solution uses Docker Compose to create a network of containers:

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  Client Web   │────▶│  ModSecurity  │────▶│  Juice Shop   │
│   Browser     │     │      WAF      │     │ Application   │
└───────────────┘     └───────────────┘     └───────────────┘
                             ▲                     ▲
                             │                     │
                             └─────────┬───────────┘
                                       │
                                       ▼
                             ┌───────────────┐
                             │  AIDE IDS     │
                             │  Monitoring   │
                             └───────────────┘
```

## Getting Started

**Prerequisites**

* Docker and Docker Compose installed
* 2GB+ RAM available for containers
* Git (for cloning the repository)

## Installation

Clone this repository:

```
git clone https://github.com/yourusername/juice-shop-waf.git
cd juice-shop-waf
```

Build the containers:

```
docker compose build
```

Start the services:

```
docker compose up -d
```

Access applications:

Protected Juice Shop: `http://localhost:9090`
Direct access to Juice Shop: `http://localhost:3000`

## Usage

### Monitoring for Intrusions

**View AIDE Logs**

AIDE continuously checks for file integrity changes and logs alerts:

```
# View real-time AIDE logs
docker compose logs -f aide-container
```

### XSS Attack Detection

```
# Attempt XSS attack
curl -v "http://localhost:9090/rest/products/search?q=%27))%20UNION%20SELECT%20id%2Cemail%2Cpassword%2C4%2C5%2C6%2C7%2C8%2C9%20from%20users%20--"

# Check logs
docker exec -it modsecurity-waf grep -A 10 "injection" /var/log/modsecurity/audit.log
```


## Configuration

## ModSecurity WAF & AIDE IDS Configuration Tables

### ModSecurity WAF Environment Variables

| Variable | Description | Options | Example |
|----------|-------------|---------|---------|
| PROXY_PASS | Target application URL | URL | http://juice-shop:3000 |
| BACKEND | Alias for PROXY_PASS | URL | http://juice-shop:3000 |
| PARANOIA | Security rule level | 1-4 | 2 |
| ANOMALY_INBOUND | Inbound threshold | 1-999 | 5 |
| ANOMALY_OUTBOUND | Outbound threshold | 1-999 | 4 |
| MODSEC_RULE_ENGINE | Rule engine mode | On/DetectionOnly/Off | DetectionOnly |
| BLOCKING_MODE | Force blocking | On/Off | Off |
| ENABLE_XSS_PROTECTION | XSS protection | 0/1 | 1 |
| ENFORCE_BODYPROC_URLENCODED | URL encoding checks | 0/1 | 1 |
| VALIDATE_UTF8_ENCODING | UTF-8 validation | 0/1 | 1 |
| LOGLEVEL | Log verbosity | debug/info/notice/warn/error | debug |
| MODSEC_AUDIT_LOG_FORMAT | Log format | JSON/Native | JSON |
| MODSEC_AUDIT_ENGINE | Audit logging | RelevantOnly/On/Off | RelevantOnly |

### Security Level Reference

| PARANOIA | Anomaly Threshold | Use Case | False Positives | Protection Level |
|----------|-------------------|----------|----------------|-----------------|
| 1 | 10 | Production | Minimal | Basic |
| 2 | 5-7 | Production | Low | Medium |
| 3 | 3-4 | Testing | Moderate | High |
| 4 | 1-2 | Lab only | Many | Maximum |

### AIDE Monitoring Rule Components

| Symbol | Meaning | Description |
|--------|---------|-------------|
| p | Permissions | File permissions and mode |
| i | Inode | Inode number |
| n | Links | Number of links |
| u | User | Owner user |
| g | Group | Owner group |
| s | Size | File size |
| m | MTime | Modification time |
| c | CTime | Change time |
| sha512 | SHA512 | SHA512 checksum |

### AIDE Monitored Locations

| Path | Purpose | Monitoring Rule |
|------|---------|----------------|
| /host/var/log/modsecurity | WAF logs | STANDARD |
| /host/etc/modsecurity | WAF config | STANDARD |
| /host/juice-shop-data | Application data | STANDARD |
| /etc/aide | AIDE configuration | p+i+u+g+sha512 |
| bin | System binaries | p+i+u+g+sha512 |
| sbin | System binaries | p+i+u+g+sha512 |



## License

MIT License

Copyright (c) 2025 pagel-pro

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
