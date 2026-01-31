# Friction log: scenario-01-weather-cache

Detailed notes on what was hard, confusing, slow, or unintuitive about solving this task using cosmic-lua.

## Summary

Overall cosmic-lua worked well for this task. The bundled modules (fetch, json, sqlite, getopt, path) covered all the requirements. The main friction points were around SQL ergonomics, URL encoding, and documentation discovery.

## Friction points

### 1. SQL injection risk with string formatting

**Severity: High**

The sqlite module's `db:exec()` requires string formatting for INSERT/UPDATE queries:

```lua
db:exec(string.format(
  [[INSERT INTO weather (city, temp) VALUES ('%s', %f)]],
  city:gsub("'", "''"),  -- manual escaping!
  temperature
))
```

I had to manually escape single quotes with `gsub("'", "''")`. This is error-prone and feels unsafe.

**Wish:** Parameterized queries for exec, like:
```lua
db:exec("INSERT INTO weather (city, temp) VALUES (?, ?)", city, temperature)
```

The `db:query()` function accepts parameters (which is great), but `db:exec()` doesn't seem to.

### 2. No URL encoding utility

**Severity: Medium**

Had to manually encode URL parameters:

```lua
local encoded_city = city:gsub(" ", "+"):gsub(",", "%%2C")
```

This is incomplete (doesn't handle all special characters) and error-prone.

**Wish:** A `url.encode()` function or similar:
```lua
local url = string.format("https://wttr.in/%s?format=j1", url.encode(city))
```

### 3. Documentation search returns too many results

**Severity: Low**

Running `--docs sqlite` returned 18 results including unrelated items like `cosmo.unix.fork` and `cosmo.unix.mapshared`. Had to run multiple queries to find the right symbols.

**Wish:** More focused search results, or a way to filter by module (e.g., `--docs cosmic.sqlite.*`).

### 4. No safe JSON decode

**Severity: Low**

Had to wrap `json.decode` in `pcall` to handle malformed JSON:

```lua
local ok, data = pcall(json.decode, result.body)
if not ok or not data then
  return nil, "invalid API response"
end
```

**Wish:** Either:
- A `json.decode_safe()` that returns `nil, error` instead of throwing
- Or documented behavior that `json.decode` returns `nil` for invalid input (if it does)

### 5. Inconsistent error handling patterns

**Severity: Low**

Different modules use different error patterns:

- `fetch.Fetch()` returns `{ok=bool, error=string, ...}`
- `sqlite.open()` returns `db, err_string`
- `db:exec()` returns `bool, err_string`

Not a big deal, but mild cognitive overhead.

**Wish:** Consistent pattern across all modules, or clear documentation of each module's error convention.

### 6. No built-in HTTP timeout control

**Severity: Low**

Couldn't find a way to set a timeout on `fetch.Fetch()`. For a weather app this is fine, but for production use I'd want:

```lua
fetch.Fetch(url, {timeout = 5000})  -- 5 second timeout
```

Maybe this exists and I missed it in the docs?

### 7. Shebang portability unclear

**Severity: Low**

I used `#!/usr/bin/env cosmic-lua` but the binary is a local `./cosmic-lua` in the project. Unclear how to make scripts portable/installable.

**Wish:** Documentation on recommended deployment patterns (install to PATH? embed scripts? etc.)

## What worked well

### Fetch module
Clean API, structured result with `ok`, `status`, `body`, `error`. Retry support mentioned in docs (didn't need it).

### SQLite query iterator
The `for row in db:query(sql, ...) do` pattern is elegant and handles cleanup automatically.

### Getopt module
Full-featured with short opts, long opts, and remaining args. Standard getopt behavior, easy to use.

### Path module
`path.join()` worked exactly as expected.

### JSON module
`json.encode()` and `json.decode()` just worked for valid input.

### Documentation system
`--docs <symbol>` with examples is helpful. The example output showing expected results is particularly nice for verification.

## Suggestions for cosmic-lua

1. **Add parameterized exec to sqlite** - This is the biggest improvement for security and ergonomics
2. **Add URL encoding utility** - Common need for HTTP clients
3. **Document error handling conventions** - Per-module or standardize
4. **Add json.try_decode or similar** - For graceful error handling
5. **Consider adding request timeout to fetch** - Production use case

## Time spent

- Reading docs and exploring modules: ~10 minutes
- Initial implementation: ~15 minutes
- Debugging cache lookup (query city vs display city): ~10 minutes
- Testing and verification: ~10 minutes

Total: ~45 minutes for a complete, working implementation. This is reasonable for the task complexity.
