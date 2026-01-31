# Friction Report: Building a Password Vault with cosmic-lua

## Task Summary

Built a command-line password manager with master password protection, Argon2 hashing, SQLite storage, and full CRUD operations using cosmic-lua release 2026-01-30-8e737d0.

## What Was Easy

### 1. Zero Installation
The cosmic-lua binary worked immediately after download. No dependencies, no installation, no PATH configuration. This was genuinely delightful - just `chmod +x` and go.

### 2. Argon2 Hashing
The `cosmo.argon2` module was straightforward and well-designed:
```lua
local hash = argon2.hash_encoded(password, salt, {})
local verified = argon2.verify(hash, password)
```
The API is minimal and correct. The default parameters are sensible (Argon2id with reasonable memory/time costs). No configuration needed unless you want to tune it.

### 3. SQLite Integration
Once I found the module (`cosmo.lsqlite3`), it worked exactly as expected. Standard SQLite API patterns worked fine:
```lua
local db = sqlite.open(DB_FILE, sqlite.OPEN_READWRITE + sqlite.OPEN_CREATE)
db:exec("CREATE TABLE ...")
local stmt = db:prepare("SELECT * FROM table WHERE id = ?")
stmt:bind_values(value)
```

### 4. File Permissions
Setting database file permissions was trivial:
```lua
unix.chmod(DB_FILE, 384)  -- 0600 in decimal
```

### 5. Core Lua Experience
Writing Lua itself was pleasant. The language is clean, and the standard library worked as expected.

## What Was Hard

### 1. Module Discovery
**Problem**: Module naming wasn't intuitive or documented upfront.

I had to discover through trial and error that modules are under the `cosmo.*` namespace:
- NOT `argon2` → YES `cosmo.argon2`
- NOT `lsqlite3` → YES `cosmo.lsqlite3`

The README showed usage examples with `require("cosmic")` (high-level utilities) but didn't make it clear that the low-level bindings are in `cosmo.*` namespace.

**Impact**: Spent 5-10 minutes trial-and-erroring module names before checking web documentation.

### 2. Documentation Not Embedded
**Problem**: Documentation requires internet access and is scattered across GitHub.

The binary has no built-in help or module listing:
```bash
./cosmic-lua --help         # No such option
./cosmic-lua --list-modules # No such option
```

I had to:
1. Open a browser
2. Navigate to GitHub
3. Find the docs branch
4. Search for the right module
5. Read the markdown

**Impact**: This broke the flow. For a "cosmopolitan" binary that's supposed to be self-contained and portable, requiring internet access for basic API discovery feels contradictory.

### 3. No Secure Password Input Function
**Problem**: No built-in way to read passwords without echoing.

Had to implement this workaround:
```lua
function read_password(prompt)
    io.write(prompt)
    io.flush()
    os.execute("stty -echo 2>/dev/null")
    local password = io.read()
    os.execute("stty echo 2>/dev/null")
    io.write("\n")
    return password
end
```

This is fragile (requires `stty`), platform-dependent, and error-prone. A password manager is a common use case, and secure input is table stakes.

**Impact**: 15 minutes to research and test this approach. The final solution works but feels hacky.

### 4. Database API Documentation Incomplete
**Problem**: The web documentation for lsqlite3 showed basic open/exec but didn't document database handle methods.

I had to guess/experiment to find:
- `db:prepare()` - not documented
- `db:nrows()` - discovered by accident (saw it used in test file)
- `stmt:bind_values()` - had to assume from standard SQLite bindings
- `stmt:step()` - had to assume
- `stmt:get_value()` - had to assume

The web docs showed constants and `open()` function signature, but not the object methods.

**Impact**: Would have been faster with complete API docs. Had to rely on SQLite knowledge from other languages.

### 5. Error Messages for Missing Modules
**Problem**: When a module doesn't exist, you get a wall of search paths:

```
module 'argon2' not found:
	no field package.preload['argon2']
	no file '/zip/.lua/argon2.tl'
	no file '/zip/.lua/argon2/init.tl'
	... (10 more lines)
```

This doesn't help me know:
- What modules ARE available
- What the correct name should be
- Where to find documentation

**Impact**: Made initial exploration frustrating.

### 6. No Examples or Templates
**Problem**: No example scripts shipped with the binary.

Would have been helpful to have embedded examples accessible via:
```bash
./cosmic-lua --example http-fetch
./cosmic-lua --example database
./cosmic-lua --example argon2
```

Or even just a `/zip/examples/` directory I could explore.

**Impact**: Had to start from scratch with no reference implementations.

## What Would Make It Easier

### High Priority

1. **Embedded Module Help**
   ```bash
   ./cosmic-lua --list-modules
   # Output:
   # Available modules:
   #   cosmo.argon2      - Password hashing (Argon2)
   #   cosmo.lsqlite3    - SQLite database
   #   cosmo.unix        - POSIX system calls
   #   ...

   ./cosmic-lua --help cosmo.argon2
   # Shows API documentation directly in terminal
   ```

2. **Secure Input Function**
   Add to `cosmo.unix`:
   ```lua
   local password = unix.getpass("Enter password: ")
   ```
   This is standard in most system libraries (Python's `getpass`, C's `getpass()`, Go's `terminal` package).

3. **Complete API Documentation**
   Either embed docs in the binary OR provide complete, comprehensive docs that cover:
   - All module functions
   - All object methods
   - All constants
   - Usage examples for each

### Medium Priority

4. **Better Error Messages**
   When `require("argon2")` fails, suggest:
   ```
   module 'argon2' not found.
   Did you mean 'cosmo.argon2'?
   Use './cosmic-lua --list-modules' to see available modules.
   ```

5. **Example Scripts**
   Ship with `/zip/examples/` containing:
   - `http-client.lua` - Using cosmic.fetch
   - `database.lua` - Using cosmo.lsqlite3
   - `password-hash.lua` - Using cosmo.argon2
   - `file-walker.lua` - Using cosmic.walk

6. **Higher-Level Database Helpers**
   The `db:nrows()` method exists but wasn't documented. More helpers like:
   ```lua
   for row in db:nrows("SELECT * FROM users") do
     print(row.id, row.name)
   end
   ```
   This pattern is much more ergonomic than prepare/bind/step/get_value loops.

### Low Priority

7. **Interactive REPL with Tab Completion**
   ```bash
   ./cosmic-lua
   > require("cosmo.ar<TAB>
   > require("cosmo.argon2")
   > argon2.<TAB>
   hash_encoded  verify
   ```
   Would make exploration much easier.

8. **Type Checking by Default**
   The binary includes Teal support, but I wrote plain Lua because:
   - Don't know how to enable type checking without web docs
   - No embedded type definition help
   - Adds complexity without clear benefit for scripts

   If type checking "just worked" with helpful errors, I might have used it.

## Overall Assessment

**Pros:**
- cosmic-lua is genuinely portable and self-contained
- The bundled libraries (Argon2, SQLite) are high-quality
- Once you know the API, it's productive
- No dependency hell

**Cons:**
- Documentation requires internet/GitHub access
- Module discovery is trial-and-error
- Missing common utilities (secure input)
- Feels like you need to already know what's available

**Recommendation:**
The biggest improvement would be **embedded documentation and module discovery**. A truly "cosmopolitan" tool should be self-documenting and usable anywhere - including on a plane, on a server without internet, or in a restricted environment.

The second biggest improvement would be **filling gaps in common use cases** - secure input being the most glaring example.

With these improvements, cosmic-lua would go from "interesting but requires homework" to "immediately productive."

## Time Breakdown

- Setting up cosmic-lua: 5 minutes
- Finding correct module names: 10 minutes
- Reading web documentation: 15 minutes
- Implementing password vault: 30 minutes
- Implementing secure input workaround: 15 minutes
- Testing and fixing bugs: 10 minutes
- Creating comprehensive tests: 10 minutes

**Total: ~95 minutes**

With embedded docs and secure input: **~45 minutes** (saved 50 minutes of friction)
