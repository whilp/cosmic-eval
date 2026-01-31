# Friction log: scenario-01-weather-cache

## Overview

Built a weather CLI tool with HTTP fetching, JSON parsing, and SQLite caching using cosmic-lua. Total time: approximately 15 minutes from start to working implementation.

## What went well

### Error messages with suggestions

When I tried the wrong module path:
```lua
require("lsqlite3")
```

The error message was excellent:
```
module 'lsqlite3' not found

Did you mean?
  cosmo.lsqlite3

Try: require("cosmo.lsqlite3")
```

This saved significant debugging time. The suggestion was exactly right.

### Familiar SQLite API

The `cosmo.lsqlite3` module uses the standard lsqlite3 API, which is well-documented elsewhere. Prepared statements, `db:nrows()`, `stmt:bind_values()` all worked as expected:

```lua
local stmt = db:prepare("SELECT * FROM weather WHERE city = ?")
stmt:bind_values(normalized_city)
for row in db:nrows("SELECT * FROM weather") do ... end
```

No surprises here - this was the smoothest part.

### JSON just works

`cosmo.DecodeJson` and `cosmo.EncodeJson` worked exactly as expected:

```lua
local ok, json = pcall(cosmo.DecodeJson, body)
```

### Path utilities

`cosmo.path.join` handled path construction cleanly:

```lua
local path = require("cosmo.path")
local db_path = path.join(home, ".weather_cache.db")
```

### HTTP fetching

Once I understood the API, `cosmo.Fetch` was straightforward:

```lua
local status, headers, body = cosmo.Fetch(url)
```

## What was confusing

### Discovering the Fetch return signature

I initially assumed Fetch returned a table:
```lua
local resp = cosmo.Fetch(url)
print(resp.status, resp.body)  -- ERROR: attempt to index a number value
```

The error revealed that the first return value was a number (the status code), so I had to experiment:
```lua
local status, headers, body = cosmo.Fetch(url)  -- correct
```

**Suggestion:** Documentation or `--help` output showing function signatures would eliminate this trial-and-error.

### Discovering what modules exist

I had no idea what modules were available. I resorted to enumerating table keys:

```lua
for k,v in pairs(require("cosmo")) do print(k, type(v)) end
```

This gave me a list of ~80 functions but no indication of:
- What each function does
- What arguments they take
- What they return
- Which other modules exist (like `cosmo.path`, `cosmo.unix`, `cosmo.lsqlite3`)

**Suggestion:** A `cosmic-lua --list-modules` command or built-in `help()` function would help significantly.

### No documentation for cosmo.* functions

Functions like `EscapePath`, `EscapeHost`, `ParseUrl`, etc. have self-explanatory names, but I had to guess:
- Does `EscapePath` do URL encoding? (Yes, it does)
- What's the difference between `EscapeSegment`, `EscapeFragment`, `EscapePath`?

I used `EscapePath` for the city name in the URL and it worked, but I wasn't confident it was the right choice.

## What was surprising

### wttr.in worked perfectly

The external API (wttr.in) worked flawlessly with cosmic-lua's Fetch. No issues with headers, SSL, or response handling. This was a pleasant surprise - HTTP "just worked."

### File I/O not needed

I didn't need any file I/O beyond SQLite. The scenario was well-suited to the available tools.

### The binary is self-contained

The cosmic-lua binary includes everything needed - Lua runtime, HTTP client, SQLite, JSON, path utilities. No external dependencies to install. This made setup trivial:

```bash
curl -sL <release-url>/cosmic-lua -o bin/cosmic-lua
chmod +x bin/cosmic-lua
```

## Suggestions for cosmic-lua

### 1. Built-in help system

```lua
help()                    -- list all modules
help("cosmo")             -- list cosmo functions
help("cosmo.Fetch")       -- show Fetch signature and description
```

Or a CLI flag:
```bash
cosmic-lua --help-api
cosmic-lua --help Fetch
```

### 2. Function signature discovery

Something like:
```lua
print(signature(cosmo.Fetch))
-- "Fetch(url: string, options?: table) -> status: number, headers: table, body: string"
```

### 3. Module listing

```bash
cosmic-lua --list-modules
# cosmo (core functions)
# cosmo.path (path manipulation)
# cosmo.unix (unix syscalls)
# cosmo.lsqlite3 (SQLite database)
# cosmo.re (regex)
# ...
```

### 4. Examples in error messages

When a function is called incorrectly, show an example:
```
Fetch: expected string url, got nil
Example: status, headers, body = cosmo.Fetch("https://example.com")
```

### 5. REPL improvements

An interactive REPL with tab-completion for module/function names would make exploration much faster than writing test scripts.

## Time breakdown

| Task | Time | Notes |
|------|------|-------|
| Download cosmic-lua | 30s | Easy, just curl |
| Discover APIs | 3 min | Enumerating tables, trial-and-error |
| Understand Fetch signature | 2 min | Error-driven discovery |
| Implement weather.lua | 5 min | Straightforward once APIs understood |
| Test all scenarios | 3 min | Fresh, cached, stale, errors |
| Debug issues | 1 min | Minimal - things mostly worked |

The API discovery phase (5 min) could be reduced to <1 min with documentation.

## Conclusion

cosmic-lua is capable and the APIs are well-designed. The main friction is **discoverability** - figuring out what's available and how to use it. Once discovered, the APIs work smoothly and predictably.

The error message suggestions (like "Did you mean cosmo.lsqlite3?") show the right philosophy - the tooling can guide users toward correct usage. Extending this to function signatures and module discovery would make the experience significantly smoother.
