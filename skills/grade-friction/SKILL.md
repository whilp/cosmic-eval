---
name: grade-friction
description: Analyze FRICTION.md from cosmic-eval runs. Use when grading eval results, reviewing friction logs, or identifying cosmic-lua improvements. Invoke with /grade-friction <path-to-artifacts>.
user-invocable: true
---

# Grading cosmic-eval friction logs

Analyze FRICTION.md and implementation files from cosmic-eval runs to identify:
1. Escape hatches that indicate missing cosmic.* wrappers
2. API confusion or learning curve issues
3. Workarounds that should be proper features
4. Issues to file on whilp/cosmic

## Grading process

### 1. Find and read artifacts

```bash
# If given a run ID
gh run download <run-id> --repo whilp/cosmic-eval -D /tmp/eval-artifacts

# Find friction logs
find /tmp/eval-artifacts -name "FRICTION.md"
```

### 2. Check for escape hatches

Scan all .lua files for suspicious patterns that indicate missing cosmic.* wrappers:

**Red flags (should have cosmic.* wrapper):**
- `unix.` - raw unix module usage (chmod, stat, etc.)
- `os.execute()` - shelling out for functionality
- `io.popen()` - shelling out to read output
- `os.getenv()` - should use cosmic wrapper if one exists

**Grep for these:**
```bash
grep -n "unix\.\|os\.execute\|io\.popen" *.lua
```

### 3. Check for API confusion

Look for patterns indicating the agent got confused:

- Used `cosmo.*` when `cosmic.*` wrapper exists
- Used lsqlite3 methods (`bind_values`, `step`) instead of cosmic.sqlite (`query`, `exec`)
- Used raw require patterns instead of cosmic modules

### 4. Analyze FRICTION.md sections

**Slowdowns**: Note time impact and root cause
- API discovery issues → docs improvement needed
- Missing functionality → new feature needed
- Naming confusion → rename or cross-reference needed

**Workarounds**: Each workaround = potential issue to file
- What was the workaround?
- What cosmic.* API would eliminate it?

**Tool Issues**: Direct bugs or limitations

### 5. Generate issue suggestions

For each friction point, suggest a GitHub issue:

```markdown
## Suggested Issues

### 1. [Title]
**Repo**: whilp/cosmic
**Evidence**: [quote from FRICTION.md or code snippet]
**Suggestion**: [what to add/fix]
```

## Output format

```markdown
# Friction Analysis: [scenario-name]

## Summary
- **Overall rating**: X/10
- **Escape hatches found**: N
- **Workarounds needed**: N
- **Time lost to friction**: ~X minutes

## Escape Hatches

| File | Line | Pattern | Suggested cosmic.* API |
|------|------|---------|------------------------|
| ... | ... | ... | ... |

## API Confusion
- [description of confusion and resolution]

## Workarounds
1. **[workaround]**: [why needed, what would fix it]

## Suggested Issues
1. [issue title] - [brief description]
2. ...

## What Went Well
- [positive observations about cosmic-lua]
```

## Example analysis

From scenario-02-password-vault:

**Escape hatches:**
- `unix.chmod()` → needs `cosmic.fs.chmod()`
- `os.execute("stty")` → needs `cosmic.tty.read_password()`
- `io.popen("stty -g")` → same as above

**API confusion:**
- Initially tried lsqlite3 `bind_values()`/`step()` before discovering `cosmic.sqlite` wrapper

**Issues to file:**
1. Add cosmic.tty.read_password()
2. Add cosmic.fs.chmod()
3. Clarify cosmic.sqlite vs lsqlite3 in docs
4. Add cosmic.crypto.encrypt/decrypt
