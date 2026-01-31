# Scenario 3: Download Mirror

## Goal

Build a robust file downloader that fetches files from HTTP URLs, verifies their integrity using checksums, tracks download history, and supports resuming interrupted downloads.

## Requirements

### Core Functionality

1. **HTTP File Downloading**
   - Download files from HTTP/HTTPS URLs
   - Support Range requests for resume capability
   - Handle redirects (301, 302, 307, 308)
   - Implement retry logic with exponential backoff (3 retries)
   - Show download progress (bytes downloaded, percentage, speed)

2. **Checksum Verification**
   - Compute SHA-256 hash of downloaded files
   - Allow optional checksum verification (compare against expected hash)
   - Store computed checksums in the database

3. **SQLite Database Tracking**
   - Track all downloads with the following schema:
     - `url` (text): Source URL
     - `filename` (text): Local filename where file was saved
     - `size` (integer): File size in bytes
     - `checksum` (text): SHA-256 hash of the file
     - `status` (text): Download status ("completed", "failed", "in_progress")
     - `started_at` (integer): Unix timestamp when download started
     - `completed_at` (integer): Unix timestamp when download completed
     - `attempts` (integer): Number of download attempts
   - Query download history
   - Avoid re-downloading files that already exist with matching checksums

4. **Resume Support**
   - If a download is interrupted, resume from the last byte downloaded
   - Use HTTP Range headers to request partial content
   - Verify partial downloads before resuming

### Command-Line Interface

- `download <url> [expected-checksum]`: Download a file from URL
- `verify <filename> <checksum>`: Verify a local file's checksum
- `list`: Show download history from database
- `retry <url>`: Retry a failed download

### Example Usage

```bash
# Download a file
$ ./downloader download https://example.com/large-file.zip
Downloading large-file.zip...
Progress: 45% (450 MB / 1000 MB) - 5.2 MB/s
^C
Download interrupted. Run 'retry' to resume.

# Resume the download
$ ./downloader retry https://example.com/large-file.zip
Resuming download of large-file.zip from byte 471859200...
Progress: 100% (1000 MB / 1000 MB) - 5.5 MB/s
Download completed!
SHA-256: a1b2c3d4e5f6...
File saved to: large-file.zip

# Download with checksum verification
$ ./downloader download https://example.com/file.tar.gz e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
Downloading file.tar.gz...
Progress: 100% (50 MB / 50 MB) - 8.1 MB/s
Download completed!
Verifying checksum... OK
File saved to: file.tar.gz

# List download history
$ ./downloader list
Download History:
  [COMPLETED] large-file.zip (1000 MB) - 2024-01-15 10:30:45
  [COMPLETED] file.tar.gz (50 MB) - 2024-01-15 10:45:12
  [FAILED] broken-link.zip (0 MB) - 2024-01-15 09:15:30 (3 attempts)

# Verify a file manually
$ ./downloader verify file.tar.gz e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
Verifying file.tar.gz...
Checksum: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
Status: OK
```

## Testing Criteria

Your implementation should demonstrate:

1. Successful HTTP downloads from real URLs
2. SHA-256 checksum computation
3. Checksum verification (matching and non-matching cases)
4. SQLite database with download tracking
5. Retry logic with exponential backoff
6. Resume capability using HTTP Range requests
7. Progress reporting during downloads
8. Error handling for:
   - Network failures
   - HTTP errors (404, 500, etc.)
   - Checksum mismatches
   - Disk space issues
   - Invalid URLs

## Notes

- You can test with publicly available files (Linux ISOs, public datasets, etc.)
- Progress reporting should update frequently but not spam the console
- For simplicity, assume single-threaded downloads (no concurrent downloads)
- File should be saved to the current directory with its original filename
- Consider implementing a timeout for stalled downloads
