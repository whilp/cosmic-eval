# Scenario 4: Web Page Archiver

## Goal

Build a tool that archives web pages by downloading their HTML content, detecting duplicates using content hashing, and maintaining an organized archive in a SQLite database.

## Requirements

### Core Functionality

1. **HTTP Fetching**
   - Fetch HTML content from provided URLs
   - Follow HTTP redirects
   - Handle common HTTP errors gracefully
   - Set a reasonable User-Agent header
   - Respect timeouts (30 seconds default)

2. **Content Deduplication**
   - Compute SHA-256 hash of page content (normalized HTML)
   - Before storing a new page, check if identical content already exists
   - If duplicate detected, create a reference instead of storing duplicate content
   - Track all URLs that point to the same content

3. **SQLite Archive Database**
   - **pages table**:
     - `id` (integer): Primary key
     - `content_hash` (text): SHA-256 hash of content
     - `content` (text): HTML content
     - `size` (integer): Content size in bytes
     - `first_seen` (integer): Unix timestamp when first archived
   - **urls table**:
     - `url` (text): The archived URL
     - `page_id` (integer): Foreign key to pages table
     - `title` (text): Page title extracted from HTML
     - `archived_at` (integer): Unix timestamp when URL was archived
     - `status_code` (integer): HTTP status code received

4. **Command-Line Interface**
   - `archive <url>`: Archive a single URL
   - `archive-list <file>`: Archive all URLs from a text file (one URL per line)
   - `search <query>`: Search archived pages by title or URL
   - `stats`: Show archive statistics (total pages, total URLs, deduplication ratio)
   - `export <url> <output-file>`: Export archived content for a URL

### Deduplication Logic

When archiving a URL:
1. Fetch the content
2. Compute SHA-256 hash
3. Check if hash exists in `pages` table
4. If exists: Add URL to `urls` table referencing existing page
5. If new: Add content to `pages` table, then add URL to `urls` table

### Example Usage

```bash
# Archive a single page
$ ./archiver archive https://example.com
Fetching https://example.com...
Status: 200 OK
Title: "Example Domain"
Content size: 1256 bytes
SHA-256: 3d4e5f6a7b8c...
Stored as new page (ID: 1)

# Archive the same page from different URL
$ ./archiver archive https://www.example.com
Fetching https://www.example.com...
Status: 200 OK
Title: "Example Domain"
Content size: 1256 bytes
SHA-256: 3d4e5f6a7b8c...
Duplicate detected! Referencing existing page (ID: 1)

# Archive multiple URLs from a file
$ ./archiver archive-list urls.txt
Processing urls.txt (150 URLs)...
Progress: 150/150
Results:
  - Archived: 87 new pages
  - Duplicates: 63 pages
  - Errors: 0

# Search the archive
$ ./archiver search "example"
Found 2 results:
  [1] https://example.com - "Example Domain" (2024-01-15 10:30:00)
  [1] https://www.example.com - "Example Domain" (2024-01-15 10:32:15)
  (Both URLs point to same content)

# Show statistics
$ ./archiver stats
Archive Statistics:
  Total URLs: 215
  Unique pages: 132
  Total content: 45.3 MB
  Deduplication ratio: 38.6%
  Space saved: 17.5 MB

# Export archived content
$ ./archiver export https://example.com page.html
Exported content to page.html (1256 bytes)
```

## Testing Criteria

Your implementation should demonstrate:

1. HTTP fetching of HTML content
2. SHA-256 hash computation for content deduplication
3. SQLite database with relational schema (pages + urls)
4. Duplicate detection working correctly
5. Batch processing of multiple URLs
6. Title extraction from HTML (basic parsing of `<title>` tag)
7. Search functionality across archived URLs
8. Statistics computation (deduplication ratio)
9. Error handling for:
   - Network failures
   - Invalid URLs
   - Timeouts
   - Non-HTML content (images, PDFs, etc.)
   - Database errors

## Notes

- For HTML parsing, you can use simple string operations to extract the `<title>` tag - no need for a full HTML parser
- Normalize content before hashing (e.g., trim whitespace, consistent line endings) for better deduplication
- Consider what to do with non-HTML responses (images, PDFs) - you can skip them or store them differently
- The deduplication ratio is calculated as: `(total_urls - unique_pages) / total_urls * 100`
- Test with real websites, but be respectful (don't hammer servers, use reasonable delays)
