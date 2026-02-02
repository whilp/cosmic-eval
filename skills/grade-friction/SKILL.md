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

### 1. Download artifacts

```bash
# If given a run ID
gh run download <run-id> --repo whilp/cosmic-eval -D /tmp/eval-artifacts

# Find the scenario directory
ls /tmp/eval-artifacts/
```

### 2. Run the grading script

Use `grade.tl` to compute objective metrics:

```bash
cd /tmp/eval-artifacts/eval-scenario-*/
cosmic /path/to/skills/grade-friction/grade.tl conversation.jsonl *.lua
```

This outputs JSON with:
- `assistant_turns` - number of API round-trips
- `tool_calls` - total tool invocations
- `tool_counts` - breakdown by tool name
- `duration_seconds` - wall clock time
- `escape_hatches` - suspicious patterns found in code
- `api_calls` - number of API calls with token usage
- `input_tokens` - total new input tokens
- `output_tokens` - total output tokens generated
- `cache_creation_tokens` - tokens written to cache
- `cache_read_tokens` - tokens read from cache

### 3. Objective metrics to report

| Metric | Source | What it indicates |
|--------|--------|-------------------|
| Assistant turns | conversation.jsonl | Complexity / back-and-forth |
| Tool calls | conversation.jsonl | Amount of work done |
| Duration (seconds) | timestamps | Total eval time |
| Escape hatches | *.lua files | Missing cosmic.* wrappers |
| Tools used | conversation.jsonl | Which capabilities needed |
| Input tokens | message.usage | New tokens sent per request |
| Output tokens | message.usage | Tokens generated |
| Cache read tokens | message.usage | Tokens served from cache (efficiency) |
| Cache creation tokens | message.usage | Tokens added to cache |

**Escape hatch patterns to flag:**
- `unix.` - raw unix module (should use cosmic.fs, cosmic.tty, etc.)
- `os.execute()` - shelling out (missing built-in API)
- `io.popen()` - shelling out to read output
- `lsqlite3` - raw SQLite (should use cosmic.sqlite)
- `cosmo.` - low-level API (should use cosmic.* wrapper if available)

### 4. Read all artifacts

Read every file in the artifact directory:

```bash
# List all files
ls -la /tmp/eval-artifacts/eval-scenario-*/

# Read each file
for f in /tmp/eval-artifacts/eval-scenario-*/*; do
  echo "=== $f ==="
  cat "$f"
done
```

This includes whatever the agent produced: source files, tests, docs, databases, configs, etc.

### 5. Subjective analysis from FRICTION.md

Read FRICTION.md and extract:

**Slowdowns**: Note time impact and root cause
- API discovery issues → docs improvement needed
- Missing functionality → new feature needed
- Naming confusion → rename or cross-reference needed

**Workarounds**: Each workaround = potential issue to file
- What was the workaround?
- What cosmic.* API would eliminate it?

**What Went Well**: Positive signal about cosmic-lua

### 6. Generate issue suggestions

For each friction point, suggest a GitHub issue:

```markdown
### [Title]
**Repo**: whilp/cosmic
**Evidence**: [quote from FRICTION.md or code snippet]
**Suggestion**: [what to add/fix]
**Artifact**: [link to GitHub Actions artifact]
```

## Output format

```markdown
# Friction Analysis: [scenario-name]

## Objective Metrics

| Metric | Value |
|--------|-------|
| Assistant turns | N |
| Tool calls | N |
| Duration | Nm Ns |
| Escape hatches | N |
| Input tokens | N |
| Output tokens | N |
| Cache read tokens | N |
| Cache creation tokens | N |

### Tool Usage
| Tool | Count |
|------|-------|
| Bash | N |
| Write | N |
| ... | ... |

### Escape Hatches Found

| File | Line | Pattern | Suggested API |
|------|------|---------|---------------|
| vault.lua | 83 | unix.chmod | cosmic.fs.chmod |
| ... | ... | ... | ... |

## Subjective Analysis

### Slowdowns
- [description] (~N minutes)

### Workarounds
1. **[workaround]**: [why needed, what would fix it]

### What Went Well
- [positive observations]

## Suggested Issues

1. **[Title]** - [brief description]
   - Evidence: [quote]
   - Artifact: [link]

## Overall Grade

- **Friction Level**: N/10 (lower is better)
- **cosmic-lua Rating**: N/10 (from FRICTION.md)
- **Recommendation**: [file N issues on whilp/cosmic]
```

## Example

From scenario-02-password-vault (run #21576913305):

**Objective:**
- 98 assistant turns
- 63 tool calls
- ~7 minutes duration
- 3 escape hatches

**Escape hatches:**
- `unix.chmod()` → needs `cosmic.fs.chmod()`
- `os.execute("stty")` → needs `cosmic.tty.read_password()`
- `io.popen("stty -g")` → same as above

**Issues filed:**
- #190: cosmic.tty.read_password()
- #191: cosmic.fs.chmod()
- #192: Clarify cosmic.sqlite vs lsqlite3
- #193: cosmic.crypto.encrypt/decrypt
