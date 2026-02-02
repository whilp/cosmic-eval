#!/usr/bin/env cosmic-lua
--- Run a single cosmic-eval scenario using Claude Code CLI.

local io = require("cosmic.io")
local path = require("cosmo.path")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local unix = require("cosmo.unix")

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
local prompt, err = io.slurp(readme_path)
if not prompt then
  print("Error reading " .. readme_path .. ": " .. (err or "unknown error"))
  os.exit(1)
end

-- Create results directory
local results_dir = path.join("o", scenario)
unix.makedirs(results_dir, tonumber("755", 8))

-- Create a temporary working directory
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local work_dir = unix.mkdtemp(path.join(tmpdir, "cosmic-eval-XXXXXX"))

-- Copy scenario files to work directory
local dir = fs.opendir(scenario_dir)
while true do
  local name = dir:read()
  if not name then break end
  if name ~= "." and name ~= ".." then
    local src = path.join(scenario_dir, name)
    local dst = path.join(work_dir, name)
    local content = io.slurp(src)
    if content then
      io.barf(dst, content)
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
}, {
  cwd = work_dir,
  env = env,
})

if not handle then
  print("Error spawning claude: " .. (spawn_err or "unknown"))
  os.exit(1)
end

-- Read stderr before calling read() which closes it
local stderr_content = handle.stderr:read() or ""

-- Read stdout and wait for exit
local ok, stdout_content, exit_code = handle:read()
stdout_content = stdout_content or ""
exit_code = exit_code or 1

-- Save results
io.barf(path.join(results_dir, "output.txt"), stdout_content)
io.barf(path.join(results_dir, "stderr.txt"), stderr_content)
io.barf(path.join(results_dir, "exit_code.txt"), tostring(exit_code))

-- Copy work directory contents to results
local work_dir_handle = fs.opendir(work_dir)
while true do
  local name = work_dir_handle:read()
  if not name then break end
  if name ~= "." and name ~= ".." then
    local src = path.join(work_dir, name)
    local dst = path.join(results_dir, name)
    local content = io.slurp(src)
    if content then
      io.barf(dst, content)
    end
  end
end
work_dir_handle:close()

-- Print output
print("Exit code: " .. tostring(exit_code))
print("")
if #stdout_content > 0 then
  print("Output (last 50 lines):")
  local lines = {}
  for line in stdout_content:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  local start = math.max(1, #lines - 49)
  for i = start, #lines do
    print(lines[i])
  end
end

if #stderr_content > 0 then
  print("")
  print("Stderr:")
  print(stderr_content)
end

-- Copy conversation JSONL if available
local home = os.getenv("HOME") or ""
local encoded_path = work_dir:gsub("/", "-")
local claude_projects = path.join(home, ".claude", "projects", encoded_path)
local ok, conv_dir = pcall(fs.opendir, claude_projects)
if ok then
  while true do
    local name = conv_dir:read()
    if not name then break end
    if name:match("%.jsonl$") then
      local src = path.join(claude_projects, name)
      local dst = path.join(results_dir, "conversation.jsonl")
      local content = io.slurp(src)
      if content then
        io.barf(dst, content)
      end
    end
  end
  conv_dir:close()
end

-- Clean up work directory
unix.rmrf(work_dir)

print("")
print("Results saved to: " .. results_dir)

os.exit(exit_code as integer)
