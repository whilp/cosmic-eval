# Friction log: scenario-01-weather-cache

## Overview

Built a weather CLI tool with HTTP fetching, JSON parsing, and SQLite caching using cosmic-lua. Total time: approximately 15 minutes from start to working implementation.

## Critical mistake: I didn't run `--help`

**I should have started with `cosmic-lua --help`.** Instead, I jumped straight to enumerating Lua tables to discover APIs. This was a significant error on my part.

The help output shows everything I needed:

```
$ cosmic-lua --help
cosmic-lua: cosmopolitan lua with bundled libraries

Cosmic options:
  --docs <query>                show documentation for module or symbol
  --examples [module]           browse examples (list all, or show module)
  ...

Available modules:
  cosmic:  benchmark, doc, ..., fetch, ..., json, ..., spawn, sqlite, ...
  cosmo:   argon2, ..., lsqlite3, path, re, ..., unix, zip
```

And `--docs` provides comprehensive documentation with examples:

```
$ cosmic-lua --docs cosmic.fetch
# fetch

 Structured HTTP fetch with optional retry.
 ...

## Examples

### get
 Example_get demonstrates a simple HTTP GET request

  local fetch = require("cosmic.fetch")
  local result = fetch.Fetch("https://httpbin.org/get")
  print("status:", result.status)
```

**The tooling I asked for in my original suggestions already exists.** I wasted time on trial-and-error when the answers were one `--help` away.

### What I should have done differently

1. Run `cosmic-lua --help` first
2. Note the `--docs` and `--examples` flags
3. Run `cosmic-lua --docs cosmic.fetch` to learn the HTTP API
4. Use `cosmic.fetch.Fetch()` (structured results) instead of `cosmo.Fetch()` (multiple returns)

### Why I didn't try --help

Honestly, I'm not sure. I think I assumed cosmic-lua would be like standard Lua where `--help` just shows basic usage flags, not API documentation. That assumption was wrong.

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

### The binary is self-contained

The cosmic-lua binary includes everything needed - Lua runtime, HTTP client, SQLite, JSON, path utilities. No external dependencies to install. This made setup trivial:

```bash
curl -sL <release-url>/cosmic-lua -o bin/cosmic-lua
chmod +x bin/cosmic-lua
```

## What was confusing (due to my mistake)

### Discovering the Fetch return signature

I used the low-level `cosmo.Fetch` which returns multiple values:
```lua
local status, headers, body = cosmo.Fetch(url)
```

Had I checked `--docs`, I would have found `cosmic.fetch.Fetch` which returns a structured result:
```lua
local fetch = require("cosmic.fetch")
local result = fetch.Fetch(url)
print(result.status, result.body, result.ok)
```

This is cleaner and harder to misuse. My implementation works but uses the lower-level API unnecessarily.

## What was surprising

### wttr.in worked perfectly

The external API (wttr.in) worked flawlessly with cosmic-lua's Fetch. No issues with headers, SSL, or response handling. HTTP "just worked."

### Documentation is comprehensive

Once I actually looked at `--docs`, it has:
- Type signatures (Teal types)
- Parameter descriptions
- Return value documentation
- Working examples with expected output

This is better than many mainstream language ecosystems.

## Remaining suggestions for cosmic-lua

Most of my original suggestions were already implemented. A few remaining ideas:

### 1. REPL tab-completion

An interactive REPL with tab-completion for module/function names would make exploration even faster.

### 2. Examples in error messages

When a function is called incorrectly, show an example:
```
Fetch: expected string url, got nil
Example: local result = fetch.Fetch("https://example.com")
```

### 3. Discoverability hint on first run

Perhaps on first run (or with `-i` for interactive), show a hint:
```
Tip: Use --docs <module> for API documentation, --examples to browse examples
```

## Time breakdown

| Task | Time | Notes |
|------|------|-------|
| Download cosmic-lua | 30s | Easy, just curl |
| Discover APIs | 3 min | Would be <30s with `--help` |
| Understand Fetch signature | 2 min | Would be instant with `--docs` |
| Implement weather.lua | 5 min | Straightforward once APIs understood |
| Test all scenarios | 3 min | Fresh, cached, stale, errors |
| Debug issues | 1 min | Minimal - things mostly worked |

**5 minutes of friction was entirely self-inflicted by not running `--help` first.**

## Conclusion

cosmic-lua has excellent documentation via `--help`, `--docs`, and `--examples`. The friction I experienced was due to my failure to check these first.

The actual APIs are well-designed, the error messages are helpful, and the self-contained binary makes distribution trivial. If I had started with `--help`, this would have been a very smooth experience.

**Lesson learned: always try `--help` first.**
