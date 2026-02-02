#!/usr/bin/env cosmic-lua
--- Run a single cosmic-eval scenario using Claude Code CLI.

local cio = require("cosmic.io")
local path = require("cosmo.path")
local child = require("cosmic.child")
local fs = require("cosmic.fs")

local scenario = arg[1]
if not scenario then
  print("Usage: run-eval.tl <scenario>")
  print("Example: run-eval.tl scenario-01-weather-cache")
  os.exit(1)
end

-- Claude binary from env or default (convert to absolute path)
local claude_bin = os.getenv("CLAUDE") or "o/claude"
if not claude_bin:match("^/") then
  local cwd = fs.getcwd()
  claude_bin = path.join(cwd, claude_bin)
end

local scenario_dir = scenario
local readme_path = path.join(scenario_dir, "README.md")

-- Read the scenario prompt
local prompt, err = cio.slurp(readme_path)
if not prompt then
  print("Error reading " .. readme_path .. ": " .. (err or "unknown error"))
  os.exit(1)
end

-- Create results directory
local results_dir = path.join("o", scenario)
fs.makedirs(results_dir)

-- Create a temporary working directory
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local work_dir = fs.mkdtemp(path.join(tmpdir, "cosmic-eval-XXXXXX"))

-- Copy scenario files to work directory
local dir = fs.opendir(scenario_dir)
while true do
  local name = dir:read()
  if not name then break end
  local src = path.join(scenario_dir, name)
  local st = fs.stat(src)
  if st and fs.is_file(st:mode()) then
    local content = cio.slurp(src)
    if content then
      cio.barf(path.join(work_dir, name), content)
    end
  end
end
dir:close()

print("Running: " .. scenario)
print("Work dir: " .. work_dir)
print("")

-- Run claude -p with the prompt
local env = {
  "PATH=" .. (os.getenv("PATH") or ""),
  "HOME=" .. (os.getenv("HOME") or ""),
  "CLAUDE_CODE_OAUTH_TOKEN=" .. (os.getenv("CLAUDE_CODE_OAUTH_TOKEN") or ""),
}

local handle, spawn_err = child.spawn({
  claude_bin,
  "-p", prompt,
  "--output-format", "text",
  "--dangerously-skip-permissions",
}, {
  cwd = work_dir,
  env = env,
  stderr = 2,  -- pass stderr through to terminal for real-time visibility
})

if not handle then
  print("Error spawning claude: " .. (spawn_err or "unknown"))
  os.exit(1)
end

-- Read stdout and wait for completion
local _, stdout_content, exit_code = handle:read()
stdout_content = stdout_content or ""
exit_code = exit_code or 1
local stderr_content = ""  -- stderr goes to terminal, not captured

-- Echo stdout for visibility
io.write(stdout_content)
io.flush()

-- Save results
cio.barf(path.join(results_dir, "output.txt"), stdout_content)
cio.barf(path.join(results_dir, "stderr.txt"), stderr_content)
cio.barf(path.join(results_dir, "exit_code.txt"), tostring(exit_code))

-- Copy work directory contents to results
local work_dir_handle = fs.opendir(work_dir)
while true do
  local name = work_dir_handle:read()
  if not name then break end
  local src = path.join(work_dir, name)
  local st = fs.stat(src)
  if st and fs.is_file(st:mode()) then
    local content = cio.slurp(src)
    if content then
      cio.barf(path.join(results_dir, name), content)
    end
  end
end
work_dir_handle:close()

print("")
print("Exit code: " .. tostring(exit_code))

-- Copy conversation JSONL if available
local home = os.getenv("HOME") or ""
local encoded_path = work_dir:gsub("/", "-")
local claude_projects = path.join(home, ".claude", "projects", encoded_path)
local found, conv_dir = pcall(fs.opendir, claude_projects)
if found then
  while true do
    local name = conv_dir:read()
    if not name then break end
    if name:match("%.jsonl$") then
      local src = path.join(claude_projects, name)
      local content = cio.slurp(src)
      if content then
        cio.barf(path.join(results_dir, "conversation.jsonl"), content)
      end
    end
  end
  conv_dir:close()
end

-- Clean up work directory
fs.rmrf(work_dir)

print("")
print("Results saved to: " .. results_dir)

os.exit(exit_code as integer)
