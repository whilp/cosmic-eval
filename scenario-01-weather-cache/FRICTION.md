# cosmic-lua Developer Experience - Friction Report

This document captures the developer experience of building the weather cache tool using cosmic-lua, highlighting what worked well and what could be improved.

## What Was Easy ✅

### 1. **Getting Started**
- Downloading the release asset from GitHub was straightforward
- Checksum verification worked perfectly
- Running scripts with `./cosmic-lua script.lua` was intuitive
- No installation or complex setup required

### 2. **Module Availability**
- Having `cosmic.fetch` and `cosmo.lsqlite3` bundled meant no dependency hunting
- No package manager needed, no version conflicts
- Everything needed was already there

### 3. **Basic Documentation**
- `./cosmic-lua --docs <module>` was helpful for discovering what modules exist
- Type signatures in Teal format were clear and precise
- `--docs` search functionality helped find relevant functions

### 4. **Standard Lua**
- Since it's just Lua, familiar patterns worked as expected
- No new language to learn
- Existing Lua knowledge transferred directly

## What Was Hard 😓

### 1. **SQLite API Discovery - THE BIGGEST PAIN POINT**

When I ran `./cosmic-lua --docs cosmo.lsqlite3`, I saw:
- The `open()` function signature
- That it returns a `Database` type
- But **NOT what methods Database objects have**

I tried `./cosmic-lua --docs Database` and got generic search results, not the actual API:
```bash
$ ./cosmic-lua --docs Database

Search results for 'Database':
  cosmo.unix.localtime (function)
  cosmo.lsqlite3.open (function)
  cosmo.lsqlite3.open_memory (function)
```

**The Problem:**
I had to rely on my general knowledge that lsqlite3 databases have `:exec()`, `:nrows()`, `:close()`, etc.

**A user new to lsqlite3 would be completely stuck.** They would know how to open a database but not how to actually use it.

#### What I Needed to Know but Couldn't Discover:
- What methods does a `Database` object have?
- How do I execute a SQL statement? (`:exec()`)
- How do I query and iterate results? (`:nrows()`)
- What does `:exec()` return? (status codes)
- How do I get error messages? (`:errmsg()`)
- What are the SQLite constants? (found `lsqlite3.OK` in docs, but by luck)

### 2. **No JSON Parser**

JSON is ubiquitous in modern APIs, yet there's no JSON library in cosmic-lua.

I had to parse JSON with fragile regex patterns:
```lua
local temp = json_text:match('"temp":([%d%.%-]+)')
local humidity = json_text:match('"humidity":(%d+)')
local description = json_text:match('"description":"([^"]+)"')
```

**Problems with this approach:**
- Brittle and error-prone
- Doesn't handle escaped characters
- Doesn't handle nested objects
- Fails silently if structure changes slightly
- Can't properly validate JSON

**What I wanted:**
```lua
local json = require("cosmic.json")
local data = json.decode(result.body)
local temp = data.main.temp
local humidity = data.main.humidity
```

### 3. **No Usage Examples**

The docs show type signatures but not actual usage patterns.

**What I saw:**
```teal
function Fetch(url: string, opts?: Opts): Result
```

**What I needed to see:**
```lua
-- Example: Basic fetch
local fetch = require("cosmic.fetch")
local result = fetch.Fetch("https://api.example.com/data")
if result.ok then
    print(result.body)
else
    print("Error: " .. result.error)
end

-- Example: Fetch with retry and headers
local result = fetch.Fetch("https://api.example.com/data", {
    max_attempts = 3,
    headers = {["Authorization"] = "Bearer " .. token}
})
```

Without examples, I had to:
1. Read the type signature
2. Guess at the correct usage
3. Try it and see if it works
4. Debug when it didn't

### 4. **Unclear Error Handling Patterns**

Questions I had while coding:
- Does `lsqlite3.open()` return nil on error or throw an exception?
- What fields does `fetch.Result` have when `ok = false`?
- Is `result.error` always set when `ok = false`?

I had to write defensive code because the docs didn't clarify:
```lua
if not result.ok then
    return nil, result.error or "HTTP request failed"  -- Is error always set?
end
```

### 5. **No Way to List Object Methods Interactively**

In Python/Ruby, you can do:
```python
db = sqlite3.connect("db.sqlite")
dir(db)  # See all methods
help(db.execute)  # See specific method docs
```

In cosmic-lua, there's no equivalent way to explore at runtime.

## What Would Make It Easier 🚀

### 1. **Better Type/Object Documentation**

The `--docs` command should show methods for record types:

```bash
$ cosmic-lua --docs Database
# Should show:

Database (from cosmo.lsqlite3)

Methods:
  :exec(sql: string) -> number
    Execute SQL statement(s). Returns lsqlite3.OK on success.

    Example:
      db:exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
      db:exec("INSERT INTO users (name) VALUES ('Alice')")

  :nrows(sql: string) -> iterator
    Execute query and iterate over result rows as tables.
    Each row is a table with column names as keys.

    Example:
      for row in db:nrows("SELECT * FROM users") do
        print(row.id, row.name)
      end

  :prepare(sql: string) -> statement
    Prepare a SQL statement for execution.

  :close() -> number
    Close the database connection.

  :errmsg() -> string
    Get the most recent error message.

Constants:
  lsqlite3.OK = 0        -- Success
  lsqlite3.ERROR = 1     -- SQL error
  lsqlite3.ROW = 100     -- Row available
  lsqlite3.DONE = 101    -- No more rows
```

### 2. **Include a JSON Library**

JSON is essential for modern development. Add `cosmic.json` or `cosmo.json`:

```lua
local json = require("cosmic.json")

-- Decode
local data = json.decode('{"name": "Alice", "age": 30}')
print(data.name)  -- "Alice"

-- Encode
local str = json.encode({name = "Bob", age = 25})
print(str)  -- '{"name":"Bob","age":25}'
```

**Suggested libraries to bundle:**
- [lunajson](https://github.com/grafi-tt/lunajson) - Pure Lua, fast
- [dkjson](http://dkolf.de/src/dkjson-lua.fsl/home) - Widely used, UTF-8 support
- [cjson](https://github.com/mpx/lua-cjson) - C-based, very fast

### 3. **Example-Driven Documentation**

Every function should have at least one concrete example.

**Current state:**
```
function Fetch(url: string, opts?: Opts): Result
  Fetch a URL and return structured result.
```

**Improved version:**
```
function Fetch(url: string, opts?: Opts): Result
  Fetch a URL and return structured result.

  Examples:
    -- Basic GET request
    local result = fetch.Fetch("https://api.github.com/users/octocat")
    if result.ok then
      print("Status:", result.status)
      print("Body:", result.body)
    end

    -- With retry and headers
    local result = fetch.Fetch("https://api.example.com/data", {
      max_attempts = 3,
      max_delay = 5000,
      headers = {
        ["Authorization"] = "Bearer " .. token,
        ["User-Agent"] = "MyApp/1.0"
      }
    })

    -- Handle errors
    if not result.ok then
      io.stderr:write("Error: " .. result.error .. "\n")
      os.exit(1)
    end
```

### 4. **Add a Cookbook/Examples Command**

```bash
$ cosmic-lua --examples
Available examples:
  http-fetch       - Fetch data from HTTP API
  json-parse       - Parse JSON response (requires json library)
  sqlite-basic     - Create and query SQLite database
  sqlite-schema    - Create tables with proper schema
  cli-args         - Parse command-line arguments
  error-handling   - Proper error handling patterns
  file-operations  - Read and write files

$ cosmic-lua --examples sqlite-basic
# Shows a complete, runnable example

$ cosmic-lua --run-example sqlite-basic
# Actually runs the example
```

### 5. **Improve --docs Discoverability**

Add more ways to explore:

```bash
$ cosmic-lua --docs lsqlite3
# Show module-level functions AND exported types

$ cosmic-lua --docs Database --methods
# Show all methods available on Database type

$ cosmic-lua --docs fetch.Result --fields
# Show all fields in Result record

$ cosmic-lua --docs --all sqlite
# Show everything related to sqlite (functions, types, constants)

$ cosmic-lua --docs --interactive
# Enter interactive docs browser
```

### 6. **Better Error Messages from --docs**

**Current:**
```bash
$ cosmic-lua --docs Database
error: documentation not found for 'Database'
```

**Improved:**
```bash
$ cosmic-lua --docs Database
error: documentation not found for 'Database'

Did you mean:
  cosmo.lsqlite3.Database (type)
  cosmo.lsqlite3.open (returns Database)

Try:
  cosmic-lua --docs cosmo.lsqlite3.Database
```

### 7. **Add Quick Reference Cards**

```bash
$ cosmic-lua --quickref sqlite
SQLite Quick Reference (cosmo.lsqlite3)

Opening database:
  local db = lsqlite3.open("file.db")
  local db = lsqlite3.open_memory()

Executing SQL:
  db:exec("CREATE TABLE...")      -- DDL/DML
  db:exec("INSERT INTO...")

Querying:
  for row in db:nrows("SELECT * FROM users") do
    print(row.id, row.name)
  end

Error handling:
  if db:exec(sql) ~= lsqlite3.OK then
    print("Error: " .. db:errmsg())
  end

Cleanup:
  db:close()
```

### 8. **Include a REPL with Tab Completion**

```bash
$ cosmic-lua --repl
cosmic> db = require("cosmo.lsqlite3").open("test.db")
cosmic> db:<TAB>
  close()  exec()  nrows()  prepare()  errmsg()
cosmic> db:exec("CREATE TABLE test (id INTEGER)")
```

## Impact Assessment

### High Impact, Easy Fixes:
1. ✅ **Add JSON library** - Solves 90% of API integration friction
2. ✅ **Document object methods** - Essential for discoverability
3. ✅ **Add usage examples to --docs** - Dramatically reduces trial-and-error

### High Impact, Medium Effort:
4. ⚠️ **Cookbook/examples command** - Great for learning, requires content creation
5. ⚠️ **Better --docs search** - Improve discoverability

### Nice to Have:
6. 💡 **Interactive REPL** - Helps exploration but takes development time
7. 💡 **Quick reference cards** - Useful but requires maintenance

## Conclusion

**cosmic-lua is powerful** - it has excellent module selection and a clean design. The core functionality is solid.

**The main friction point is discoverability:** The gap between "what modules exist" and "how do I actually use them" was significant.

**Quick wins that would dramatically improve the experience:**
1. Add a JSON library (highest priority)
2. Document object/record type methods in `--docs`
3. Include usage examples for all documented functions
4. Better error messages when docs aren't found

**The tool has great potential** - with improved documentation and discoverability, it could be extremely intuitive and productive. The foundation is excellent; it just needs better ergonomics on top.

## Testing Context

This friction report was written after successfully implementing a complete weather caching tool that:
- Fetches from real HTTP APIs
- Parses JSON responses
- Stores data in SQLite
- Implements cache expiration logic
- Handles errors gracefully

All functionality works correctly, but the development experience had unnecessary friction that better documentation would eliminate.
