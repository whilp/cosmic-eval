# Friction Log: Scenario 01 - Weather Cache

Implementation of a weather data cache using cosmic-lua from the `2026-01-31-c95fcb4` prerelease.

## What Went Well

### Helpful Error Messages
When I tried `require("lsqlite3")`, the error message was excellent:
```
module 'lsqlite3' not found

Did you mean?
  cosmo.lsqlite3

Try: require("cosmo.lsqlite3")
```
This immediately pointed me to the correct path. More tools should do this.

### Familiar SQLite API
The lsqlite3 bindings work exactly as expected from standard Lua SQLite libraries:
```lua
local db = sqlite.open(path)
local stmt = db:prepare("SELECT * FROM table WHERE col = ?")
stmt:bind_values(value)
stmt:step()
stmt:finalize()
```
No surprises here - this was straightforward.

### HTTP Fetching
`cosmo.Fetch` has a clean interface that returns status, headers, body:
```lua
local status, headers, body = cosmo.Fetch(url)
```
Easy to use and the return values are intuitive.

### JSON Handling
`cosmo.DecodeJson` works as expected and handles errors gracefully with pcall:
```lua
local ok, data = pcall(cosmo.DecodeJson, body)
```

### Single Binary Distribution
Having everything bundled in one ~6MB binary that includes Lua, SQLite, HTTP client, and JSON support is convenient. No dependency management needed.

## Friction Points

### Missed the Welcome Experience
**Issue:** The welcome message with quick-start tips only appears when entering the interactive REPL, not when using `-e` or running scripts.

My natural workflow was to test things incrementally with `-e`:
```bash
./bin/cosmic-lua -e 'print("Hello")'
./bin/cosmic-lua -e 'local cosmo = require("cosmo"); ...'
```

I never entered the REPL, so I never saw:
```
Welcome to cosmic-lua!

Quick start:
  cosmic --docs <query>    search documentation
  cosmic --help            show all options
  help()                   search docs from REPL
```

This meant I didn't know about `--docs` or `--help` until much later when explicitly asked to check `--welcome`.

**Root cause:** The welcome is gated on `is_tty and REPL mode` (see `main.tl:257`). Using `-e` bypasses the REPL entirely.

**Impact:** I manually enumerated functions with `for k,v in pairs(cosmo)` when `--docs cosmo` would have shown me everything with documentation.

**Suggestion:** Consider showing welcome on first `-e` usage too, or at least print a one-liner like:
```
Tip: Run 'cosmic --help' to see available options
```

### Module Path Discovery
**Issue:** No obvious way to discover what modules are available.

I had to guess that SQLite would be `cosmo.lsqlite3`. While the error message helped, I had no way to know upfront what modules exist without trial and error.

**Suggestion:** A `cosmic-lua --list-modules` flag or documentation of available modules would help.

### URL Encoding Function Names
**Issue:** I assumed JavaScript-style `EncodeURIComponent` would exist. It doesn't.

I had to enumerate all functions to find the right one:
```lua
for k, v in pairs(cosmo) do print(k, type(v)) end
```

This revealed many URL-related functions with non-obvious names:
- `EscapeParam` - what I needed
- `EscapeSegment` - also works for my use case
- `EscapeHost`, `EscapeUser`, `EscapePass`, `EscapePath`, `EscapeFragment`
- `EncodeUrl` - takes a table, not a string (unexpected)

**Confusion:** The distinction between `EscapeParam` and `EscapeSegment` is unclear. Both produced the same output for "New York" → "New%20York". When would I use one vs the other?

**Suggestion:**
- Add an alias like `UrlEncode(str)` for the common case
- Document what each escape function is for

### EncodeUrl Expects a Table
**Issue:** `cosmo.EncodeUrl("string")` fails with "table expected, got string".

This was unexpected. Most URL encoding functions in other languages take a string. I never figured out what table format it expects.

**Suggestion:** Document the expected table structure or rename to `EncodeUrlFromParts` to make it clear.

### No Version Flag
**Issue:** `--version` is not recognized:
```
$ cosmic-lua --version
cosmic-lua: unknown option '--version'
Lua 5.4
```

The `-v` flag shows "Lua 5.4" but not the cosmic-lua version itself.

**Suggestion:** Add `--version` to show both cosmic-lua release and Lua version.

### API Discovery - The Docs I Didn't Know Existed
**Issue:** I didn't know `--docs` existed because I never saw the welcome message.

What I did (the hard way):
```lua
for k, v in pairs(require("cosmo")) do print(k, type(v)) end
```

What I should have done:
```bash
cosmic-lua --docs cosmo
cosmic-lua --docs EscapeParam
```

The documentation system exists and is good! But the welcome message that tells you about it only appears in interactive REPL mode. Since I used `-e` exclusively, I never discovered it.

**This is the core friction:** The tool has good docs, but the pathway to discovering them is too narrow.

### Shebang Path
**Minor issue:** I used `#!/usr/bin/env cosmic-lua` in my script, but this requires cosmic-lua to be in PATH. Since I'm using a local binary in `./bin/cosmic-lua`, I had to invoke it explicitly:
```bash
./bin/cosmic-lua weather London
```

Not really a friction point, just a deployment consideration.

## Summary

| Aspect | Rating | Notes |
|--------|--------|-------|
| Getting started | ⭐⭐⭐ | Welcome only shows in REPL, missed it entirely |
| SQLite | ⭐⭐⭐⭐⭐ | Standard API, no surprises |
| HTTP client | ⭐⭐⭐⭐ | Clean interface |
| JSON | ⭐⭐⭐⭐⭐ | Works as expected |
| API discoverability | ⭐⭐ | Had to enumerate functions manually |
| URL encoding | ⭐⭐ | Many functions, unclear which to use |
| Documentation | ⭐⭐⭐ | `--docs` exists but I didn't know about it! |
| Error messages | ⭐⭐⭐⭐⭐ | "Did you mean?" is excellent |

## Time Spent

- Understanding cosmic-lua modules: ~5 min (trial and error)
- Finding URL encoding function: ~3 min (enumerated all functions)
- Actual implementation: ~10 min
- Testing: ~5 min

The tool is usable but would benefit from better discoverability. The "Did you mean?" error messages show the right philosophy - extending that to proactive documentation would make the tool much more approachable.
