# Scenario 6: Parallel Task Runner

## Goal

Build a command-line tool that executes shell commands as subprocess tasks, supporting parallel execution with concurrency limits, dependency ordering, output capture, and result tracking in a SQLite database.

## Requirements

### Core Functionality

1. **Task Definition**
   - Read task definitions from a simple line-based format:
     ```
     # Comments start with #
     task_name: command arg1 arg2
     dependent_task: command --flag [after:task_name]
     ```
   - Each task has:
     - Name (unique identifier)
     - Command to execute (passed to shell)
     - Optional dependencies via `[after:name1,name2]` suffix
   - Validate that dependencies reference existing tasks
   - Detect circular dependencies and report errors

2. **Process Execution**
   - Execute each task as a subprocess using execvp/spawn
   - Capture stdout and stderr separately for each task
   - Record exit code for each task
   - Implement configurable timeout per task (default 60 seconds)
   - Kill timed-out processes and mark as failed
   - Handle signals (SIGTERM, SIGINT) gracefully:
     - Forward signal to running child processes
     - Wait for children to exit before self-terminating

3. **Parallel Execution**
   - Run independent tasks in parallel
   - Respect `--jobs N` flag for maximum concurrent processes (default: number of CPUs)
   - Tasks with dependencies wait for their dependencies to complete
   - If a dependency fails:
     - Skip dependent tasks
     - Mark them as "skipped" (not "failed")
   - Continue running other independent tasks even if some fail

4. **SQLite Result Storage**
   - Store run history in `runs` table:
     - `id` (integer): Primary key
     - `started_at` (integer): Unix timestamp when run started
     - `finished_at` (integer): Unix timestamp when run finished
     - `total_tasks` (integer): Number of tasks in run
     - `passed` (integer): Count of successful tasks
     - `failed` (integer): Count of failed tasks
     - `skipped` (integer): Count of skipped tasks
   - Store task results in `tasks` table:
     - `id` (integer): Primary key
     - `run_id` (integer): Foreign key to runs
     - `name` (text): Task name
     - `command` (text): Command that was executed
     - `status` (text): "passed", "failed", "skipped", "timeout"
     - `exit_code` (integer): Process exit code (null if skipped)
     - `started_at` (integer): Unix timestamp
     - `finished_at` (integer): Unix timestamp
     - `duration_ms` (integer): Execution time in milliseconds
     - `stdout` (text): Captured standard output
     - `stderr` (text): Captured standard error

5. **Command-Line Interface**
   - `run <taskfile>`: Execute tasks from file
   - `run <taskfile> --jobs N`: Limit concurrent processes
   - `run <taskfile> --timeout S`: Set per-task timeout in seconds
   - `run <taskfile> --task NAME`: Run only specific task (and its dependencies)
   - `history`: Show recent runs with summary
   - `show <run_id>`: Show details of a specific run
   - `show <run_id> --task NAME`: Show output of specific task in a run
   - `retry <run_id>`: Re-run only failed/skipped tasks from a previous run

### Example Usage

```bash
# Example task file (tasks.txt)
$ cat tasks.txt
# Build pipeline
fetch_deps: npm install
lint: npm run lint [after:fetch_deps]
typecheck: npm run typecheck [after:fetch_deps]
unit_tests: npm test [after:lint,typecheck]
build: npm run build [after:unit_tests]
integration: npm run test:integration [after:build]

# Run all tasks with default concurrency
$ ./taskrun run tasks.txt
[1/6] fetch_deps: npm install
[2/6] lint: npm run lint ............... PASSED (2.3s)
[2/6] typecheck: npm run typecheck ..... PASSED (4.1s)
[3/6] unit_tests: npm test ............. PASSED (12.4s)
[4/6] build: npm run build ............. PASSED (8.7s)
[5/6] integration: npm run test:int .... FAILED (3.2s)

Run completed: 5 passed, 1 failed, 0 skipped
Results saved to: taskrun.db (run #42)

# Run with limited concurrency
$ ./taskrun run tasks.txt --jobs 2
Running with max 2 concurrent tasks...

# Run single task (with dependencies)
$ ./taskrun run tasks.txt --task unit_tests
[1/3] fetch_deps: npm install .......... PASSED (15.2s)
[2/3] lint: npm run lint ............... PASSED (2.3s)
[2/3] typecheck: npm run typecheck ..... PASSED (4.1s)
[3/3] unit_tests: npm test ............. PASSED (12.4s)

# Show history
$ ./taskrun history
Recent runs:
  #42 | 2024-01-15 14:30:22 | 5 passed, 1 failed, 0 skipped | 30.7s
  #41 | 2024-01-15 14:15:10 | 6 passed, 0 failed, 0 skipped | 32.1s
  #40 | 2024-01-15 13:45:03 | 4 passed, 2 failed, 0 skipped | 25.3s

# Show run details
$ ./taskrun show 42
Run #42 (2024-01-15 14:30:22)
Duration: 30.7s

Tasks:
  fetch_deps .... PASSED (15.2s)
  lint .......... PASSED (2.3s)
  typecheck ..... PASSED (4.1s)
  unit_tests .... PASSED (12.4s)
  build ......... PASSED (8.7s)
  integration ... FAILED (3.2s)

# Show task output
$ ./taskrun show 42 --task integration
Task: integration
Command: npm run test:integration
Status: FAILED (exit code 1)
Duration: 3.2s

--- stdout ---
Running integration tests...
  ✓ API health check
  ✓ User creation
  ✗ Payment processing

--- stderr ---
Error: Connection refused to payment gateway

# Retry failed tasks
$ ./taskrun retry 42
Retrying 1 failed task from run #42...
[1/1] integration: npm run test:int .... PASSED (3.4s)

Run completed: 1 passed, 0 failed, 0 skipped
Results saved to: taskrun.db (run #43)
```

### Example: Dependency Failure Propagation

```bash
$ cat pipeline.txt
compile: gcc -c main.c
link: gcc -o main main.o [after:compile]
test: ./main --test [after:link]
package: tar czf release.tar.gz main [after:test]

# If compile fails:
$ ./taskrun run pipeline.txt
[1/4] compile: gcc -c main.c ........... FAILED (0.1s)
[2/4] link ............................ SKIPPED (dependency failed)
[3/4] test ............................ SKIPPED (dependency failed)
[4/4] package ......................... SKIPPED (dependency failed)

Run completed: 0 passed, 1 failed, 3 skipped
```

### Example: Timeout Handling

```bash
$ ./taskrun run tasks.txt --timeout 5
[1/3] quick_task: echo hello ........... PASSED (0.01s)
[2/3] slow_task: sleep 60 .............. TIMEOUT (5.0s)
[3/3] final: echo done ................. SKIPPED (dependency failed)

Run completed: 1 passed, 1 timeout, 1 skipped
```

## Testing Criteria

Your implementation should demonstrate:

1. **Process spawning**: Use execvp/spawn to execute commands as subprocesses
2. **Parallel execution**: Run multiple processes concurrently up to the job limit
3. **Process I/O capture**: Capture stdout and stderr from child processes via pipes
4. **Exit code handling**: Correctly capture and interpret process exit codes
5. **Process termination**: Kill processes that exceed the timeout
6. **Signal handling**: Forward SIGTERM/SIGINT to child processes, clean up properly
7. **Dependency graph**: Topological sort of tasks, detect cycles
8. **Concurrency control**: Limit concurrent processes, schedule ready tasks
9. **Error handling** for:
   - Invalid task file syntax
   - Circular dependencies
   - Missing dependency references
   - Failed process spawning
   - Database errors
   - Signal interruption during execution

## Notes

- Commands are executed via shell (`/bin/sh -c "command"`) to support pipes and redirects
- Task names must be alphanumeric with underscores (e.g., `build_prod`, `test_unit`)
- Output should show real-time progress with task status updates
- Consider memory limits for captured output (e.g., truncate stdout/stderr at 1MB)
- The tool should work correctly when tasks produce large amounts of output
- Use non-blocking I/O or separate threads/processes to read stdout/stderr while process runs
- Database path can be specified with `--db` flag (default: `taskrun.db`)
