# Friction log: scenario-01-weather-cache

## Overview

Built a weather CLI tool with HTTP fetching, JSON parsing, and SQLite caching using cosmic-lua. Total time: approximately 15 minutes from start to working implementation.

## Critical mistake: I didn't try the obvious things

**I should have started with `cosmic-lua --help` or `cosmic-lua -i` then `help()`.** Instead, I jumped straight to enumerating Lua tables to discover APIs. This was a significant error.

### Discovery path 1: `--help`

```
$ cosmic-lua --help
...
  --docs <query>              show documentation for module or symbol
  --examples [module]         browse examples
...
Available modules:
  cosmic:  benchmark, doc, ..., fetch, ..., json, ..., spawn, sqlite, ...
  cosmo:   argon2, ..., lsqlite3, path, re, ..., unix, zip
```

### Discovery path 2: REPL `help()`

```
$ cosmic-lua -i
> help()
Cosmo Lua Help System

Modules:
  cosmo            - Encoding, hashing, compression, networking
  cosmo.unix       - POSIX system calls
  cosmo.path       - Path manipulation
  cosmo.re         - Regular expressions
  cosmo.lsqlite3   - SQLite database
  ...

Usage:
  help()                      - This overview
  help("cosmo")               - List top-level functions
  help("cosmo.Fetch")         - Show function documentation
  help.search("base64")       - Search for matching functions
```

And `help("cosmo.Fetch")` gives comprehensive documentation including the return signature:

```
Returns:
  integer: status, table<string,string> headers, string body
```

**Both paths give exactly what I needed. I used neither.**

### Why I didn't try them

Standard Lua has no built-in discovery mechanism. The idiomatic approach is:

```lua
for k,v in pairs(module) do print(k, type(v)) end
```

There's no `help()` function, no `--docs` flag, no tab-completion. Documentation is entirely external (lua.org, LuaRocks pages, README files).

**I applied a standard-Lua mental model to cosmic-lua.** Lua users have learned that:
- `--help` just shows flags like `-e`, `-i`, `-v`
- The REPL has no special functions
- You discover APIs by reading external docs or enumerating tables

cosmic-lua breaks these expectations in a good way, but my prior experience led me to skip the checks that would have revealed this.

### The suggestion that might actually help

Since Lua users have learned that `--help` and `help()` don't help with API discovery, they won't try them. A hint on REPL startup could bridge this gap:

```
$ cosmic-lua -i
Lua 5.4  Copyright (C) 1994-2024 Lua.org, PUC-Rio
Type help() for module documentation
>
```

This signals that cosmic-lua is different from standard Lua without being intrusive.

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

Had I checked `help("cosmo.Fetch")` or `--docs cosmic.fetch`, I would have:
1. Seen the return signature clearly documented
2. Found `cosmic.fetch.Fetch` which returns a structured result:

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

Once I actually looked at `help()` and `--docs`, they provide:
- Full function signatures with types
- Parameter descriptions
- Return value documentation
- Working examples with expected output

This is better than many mainstream language ecosystems.

## Remaining suggestions for cosmic-lua

Most of my original suggestions were already implemented. The one that might help:

### REPL startup hint

```
$ cosmic-lua -i
Lua 5.4  Copyright (C) 1994-2024 Lua.org, PUC-Rio
Type help() for module documentation
>
```

This bridges the gap for users coming from standard Lua who have learned that `help()` doesn't exist.

## Time breakdown

| Task | Time | Notes |
|------|------|-------|
| Download cosmic-lua | 30s | Easy, just curl |
| Discover APIs | 3 min | Would be <30s with `help()` |
| Understand Fetch signature | 2 min | Would be instant with `help("cosmo.Fetch")` |
| Implement weather.lua | 5 min | Straightforward once APIs understood |
| Test all scenarios | 3 min | Fresh, cached, stale, errors |
| Debug issues | 1 min | Minimal - things mostly worked |

**5 minutes of friction was self-inflicted by applying standard-Lua expectations to cosmic-lua.**

## Conclusion

cosmic-lua has excellent documentation via `--help`, `--docs`, and the REPL `help()` function. The friction I experienced came from assuming cosmic-lua would behave like standard Lua, where these discovery mechanisms don't exist.

The APIs are well-designed, error messages are helpful, and the self-contained binary makes distribution trivial. A small hint on REPL startup could help users with Lua experience discover the enhanced tooling faster.

**Lesson learned: don't assume a tool lacks features just because the ecosystem it's based on lacks them.**
