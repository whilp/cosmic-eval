#!/usr/bin/env cosmic-lua
--- Run a single cosmic-eval scenario using Claude Code CLI.

local io = require("cosmic.io")
local path = require("cosmo.path")
local spawn = require("cosmic.spawn")
local fs = require("cosmic.fs")
local unix = require("cosmo.unix")

local scenario = arg[1]
if not scenario then
  print("Usage: run-eval.tl <scenario>")
  print("Example: run-eval.tl scenario-01-weather-cache")
  os.exit(1)
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
local results_dir = path.join("results", scenario)
unix.makedirs(results_dir, tonumber("755", 8))

-- Create a temporary working directory
local work_dir = os.getenv("TMPDIR") or "/tmp"
work_dir = path.join(work_dir, "cosmic-eval-" .. scenario .. "-" .. tostring(os.time()))
unix.makedirs(work_dir, tonumber("755", 8))

-- Copy scenario files to work directory
for entry in fs.opendir(scenario_dir):iter() do
  if entry.name ~= "." and entry.name ~= ".." then
    local src = path.join(scenario_dir, entry.name)
    local dst = path.join(work_dir, entry.name)
    local content = io.slurp(src)
    if content then
      io.barf(dst, content)
    end
  end
end

print("Running: " .. scenario)
print("Work dir: " .. work_dir)
print("")

-- Run claude -p with the prompt
local result = spawn.run({
  "claude",
  "-p", prompt,
  "--output-format", "text",
}, {
  cwd = work_dir,
  env = {
    PATH = os.getenv("PATH"),
    HOME = os.getenv("HOME"),
    CLAUDE_CODE_OAUTH_TOKEN = os.getenv("CLAUDE_CODE_OAUTH_TOKEN"),
  },
})

-- Save results
io.barf(path.join(results_dir, "output.txt"), result.stdout or "")
io.barf(path.join(results_dir, "stderr.txt"), result.stderr or "")
io.barf(path.join(results_dir, "exit_code.txt"), tostring(result.code))

-- Copy work directory contents to results
for entry in fs.opendir(work_dir):iter() do
  if entry.name ~= "." and entry.name ~= ".." then
    local src = path.join(work_dir, entry.name)
    local dst = path.join(results_dir, entry.name)
    local content = io.slurp(src)
    if content then
      io.barf(dst, content)
    end
  end
end

-- Print output
print("Exit code: " .. tostring(result.code))
print("")
if result.stdout and #result.stdout > 0 then
  print("Output (last 50 lines):")
  local lines = {}
  for line in result.stdout:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  local start = math.max(1, #lines - 49)
  for i = start, #lines do
    print(lines[i])
  end
end

if result.stderr and #result.stderr > 0 then
  print("")
  print("Stderr:")
  print(result.stderr)
end

-- Clean up work directory
unix.rmrf(work_dir)

print("")
print("Results saved to: " .. results_dir)

os.exit(result.code)
