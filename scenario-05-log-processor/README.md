# Scenario 5: Log File Processor

## Goal

Build a tool that processes web server access logs, extracts meaningful information, computes statistics, and stores the results in a SQLite database for querying and analysis.

## Requirements

### Core Functionality

1. **Log File Parsing**
   - Parse Common Log Format (CLF) or Combined Log Format used by Apache/Nginx
   - Example log line:
     ```
     127.0.0.1 - frank [10/Oct/2024:13:55:36 -0700] "GET /index.html HTTP/1.1" 200 2326
     ```
   - Extract fields:
     - IP address
     - User identifier (usually `-`)
     - Username (from HTTP auth, usually `-`)
     - Timestamp
     - HTTP method
     - Request path
     - HTTP version
     - Status code
     - Response size in bytes

2. **SQLite Storage**
   - Store parsed log entries in a `requests` table:
     - `id` (integer): Primary key
     - `ip_address` (text): Client IP
     - `timestamp` (integer): Unix timestamp
     - `method` (text): HTTP method (GET, POST, etc.)
     - `path` (text): Request path
     - `status_code` (integer): HTTP status code
     - `response_size` (integer): Response size in bytes
   - Create indexes on commonly queried fields (ip_address, timestamp, status_code)

3. **Statistics and Analysis**
   - Compute and store summary statistics:
     - Total requests
     - Unique IP addresses
     - Requests by HTTP method (GET, POST, etc.)
     - Requests by status code (200, 404, 500, etc.)
     - Top 10 most requested paths
     - Top 10 IP addresses by request count
     - Total bandwidth served (sum of response sizes)
     - Average response size
     - Time range of logs (first and last timestamp)

4. **Command-Line Interface**
   - `process <logfile>`: Parse a log file and store entries in database
   - `stats`: Display overall statistics
   - `top-paths [N]`: Show top N most requested paths (default 10)
   - `top-ips [N]`: Show top N most active IP addresses (default 10)
   - `errors`: Show all requests with 4xx or 5xx status codes
   - `query --ip <ip>`: Show all requests from a specific IP
   - `query --path <path>`: Show all requests for a specific path
   - `query --status <code>`: Show all requests with a specific status code

### Example Usage

```bash
# Process a log file
$ ./logproc process access.log
Processing access.log...
Parsed 15,847 log entries
Stored in database: logs.db

# Show overall statistics
$ ./logproc stats
Log Statistics:
  Total requests: 15,847
  Unique IPs: 1,203
  Date range: 2024-01-10 00:00:15 to 2024-01-15 23:59:58
  Total bandwidth: 487.3 MB
  Average response: 31.2 KB

Requests by method:
  GET: 14,521 (91.6%)
  POST: 1,104 (7.0%)
  HEAD: 189 (1.2%)
  PUT: 33 (0.2%)

Requests by status:
  200: 13,456 (84.9%)
  304: 1,891 (11.9%)
  404: 387 (2.4%)
  500: 89 (0.6%)
  Other: 24 (0.2%)

# Show top requested paths
$ ./logproc top-paths 5
Top 5 Most Requested Paths:
  1. /index.html - 3,421 requests
  2. /api/users - 1,876 requests
  3. /static/app.js - 1,654 requests
  4. /static/style.css - 1,632 requests
  5. /api/posts - 891 requests

# Show top IPs
$ ./logproc top-ips 3
Top 3 Most Active IP Addresses:
  1. 192.168.1.100 - 487 requests
  2. 10.0.0.5 - 321 requests
  3. 172.16.0.10 - 298 requests

# Show errors
$ ./logproc errors
Requests with errors (476 total):
  [404] 2024-01-12 14:23:11 | 203.0.113.5 | GET /missing.html
  [500] 2024-01-12 15:07:45 | 198.51.100.3 | POST /api/process
  [404] 2024-01-12 16:12:33 | 192.0.2.8 | GET /old-page.php
  ... (showing first 50)

# Query specific IP
$ ./logproc query --ip 192.168.1.100
Requests from 192.168.1.100 (487 total):
  2024-01-10 08:15:23 | GET /index.html | 200 | 2.3 KB
  2024-01-10 08:15:24 | GET /static/app.js | 200 | 45.1 KB
  2024-01-10 08:16:01 | POST /api/login | 200 | 156 bytes
  ... (showing first 50)

# Query specific path
$ ./logproc query --path /api/users
Requests to /api/users (1,876 total):
  2024-01-10 09:12:45 | 203.0.113.5 | GET | 200 | 4.5 KB
  2024-01-10 09:15:23 | 198.51.100.3 | GET | 200 | 4.6 KB
  2024-01-10 09:18:56 | 192.0.2.8 | POST | 201 | 234 bytes
  ... (showing first 50)
```

## Testing Criteria

Your implementation should demonstrate:

1. Successful parsing of Common/Combined Log Format
2. Timestamp parsing and conversion to Unix timestamps
3. SQLite database creation with proper schema
4. Bulk INSERT operations for log entries
5. SQL aggregation queries for statistics
6. SQL ORDER BY and LIMIT for top-N queries
7. SQL WHERE clauses for filtering
8. Error handling for:
   - Malformed log lines
   - Invalid timestamps
   - Missing files
   - Database errors
   - Out-of-memory for very large log files

## Notes

- You can generate test log data or use sample Apache/Nginx logs
- Common Log Format: `IP - USER [TIMESTAMP] "METHOD PATH PROTOCOL" STATUS SIZE`
- Combined Log Format adds referrer and user-agent (you can ignore these for simplicity)
- Timestamp format: `[10/Oct/2024:13:55:36 -0700]` (day/month/year:hour:min:sec timezone)
- For large log files, use batch inserts (e.g., 1000 rows at a time) for better performance
- Consider skipping malformed lines rather than failing completely
- Display human-readable sizes (KB, MB, GB) in statistics output
